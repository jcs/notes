require "cgi"
require "uri"
require "net/https"
require "socket"
require "ipaddr"
require "securerandom"
require "stringio"

require "active_support/hash_with_indifferent_access"

class CaseInsensitiveHash < HashWithIndifferentAccess
  def [](key)
    super convert_key(key)
  end

protected
  def convert_key(key)
    key.respond_to?(:downcase) ? key.downcase : key
  end
end

module Net
  class HTTP
    attr_accessor :address, :custom_conn_address, :skip_close

    def start  # :yield: http
      if block_given? && !skip_close
        begin
          do_start
          return yield(self)
        ensure
          do_finish
        end
      end
      do_start
      self
    end

  private
    def conn_address
      if self.custom_conn_address.to_s != ""
        self.custom_conn_address
      else
        address
      end
    end
  end
end

class SpongeResponse
  attr_reader :from_uri

  def initialize(net_http_res, from_uri = nil)
    @res = net_http_res
    @from_uri = from_uri
  end

  def inspect
    "<#{self.class} from #{self.from_uri.to_s}: status=#{self.status} " <<
      "body=#{self.body ? self.body.to_s[0, 100] : nil}>"
  end

  def body
    @res.body
  end

  def status
    @res.code.to_i
  end

  def headers
    return @headers if @headers

    @headers = CaseInsensitiveHash.new(@res.to_hash)
    @headers.each do |k,v|
      @headers[k] = v[0]
    end
    @headers
  end

  def json
    @json ||= JSON.parse(@res.body)
  end

  def ok?
    (200 .. 299).include?(status)
  end

  def to_s
    @res.body
  end
end

class Sponge
  MAX_TIME = 60
  MAX_DNS_TIME = 10
  MAX_KEEP_ALIVE_TIME = 30

  @@KEEP_ALIVES = {}

  attr_accessor :debug, :follow_redirection, :use_custom_resolver,
    :keep_alive, :timeout, :use_private_keepalives, :resolve_cache,
    :avoid_badnets, :local_ip, :user_agent

  # rfc3330
  BAD_NETS = [
    "0.0.0.0/8",
    "10.0.0.0/8",
    "127.0.0.0/8",
    "169.254.0.0/16",
    "172.16.0.0/12",
    "192.0.2.0/24",
    "192.88.99.0/24",
    "192.168.0.0/16",
    "198.18.0.0/15",
    "224.0.0.0/4",
    "240.0.0.0/4"
  ]

  # old api
  def self.fetch(uri, headers = {}, limit = 10)
    s = Sponge.new
    s.fetch(uri, "get", nil, nil, headers, {}, limit)
  end

  def initialize
    @cookies = {}
    @follow_redirection = true
    @use_custom_resolver = true
    @keep_alive = false
    @timeout = MAX_TIME
    @use_private_keepalives = false
    @resolve_cache = {}
    @local_ip = nil
    @json = nil
    @user_agent = "sponge/1.0"

    @avoid_badnets = true
    begin
      if defined?(Rails) && Rails.env.development?
        @avoid_badnets = false
      end
    rescue
    end

    @KEEP_ALIVES = {}
  end

  def close_stale_keep_alives
    [ @KEEP_ALIVES, @@KEEP_ALIVES ].each do |ka|
      ka.keys.each do |h|
        if Time.now - ka[h][:last] > MAX_KEEP_ALIVE_TIME
          begin
            ka[h][:obj].finish
          rescue IOError
          end
          ka.delete(h)
        end
      end
    end
  end

  def find_keep_alive_for(host)
    where = @@KEEP_ALIVES
    if self.use_private_keepalives
      where = @KEEP_ALIVES
    end

    if !where[host]
      return nil
    end

    return where[host][:obj]
  end

  def save_keep_alive(host, obj)
    where = @@KEEP_ALIVES
    if self.use_private_keepalives
      where = @KEEP_ALIVES
    end

    if obj == nil
      if where[host]
        begin
          where[host][:obj].finish
        rescue IOError
        end
        where.delete(host)
      end
    else
      where[host] = { :last => Time.now, :obj => obj }
    end
  end

  def set_cookie(from_host, cookie_line)
    cookie = { "domain" => from_host }

    cookie_line.split(/; ?/).each do |chunk|
      pieces = chunk.split("=")

      cookie[pieces[0]] = pieces[1]
      if pieces[0].match(/^(path|domain|httponly)$/i)
        cookie[pieces[0]] = pieces[1]
      else
        cookie["name"] = pieces[0]
        cookie["value"] = pieces[1]
      end
    end

    dputs "setting cookie #{cookie["name"]} on domain #{cookie["domain"]} " +
      "to #{cookie["value"].inspect}"

    if !@cookies[cookie["domain"]]
      @cookies[cookie["domain"]] = {}
    end

    if cookie["value"].to_s == ""
      @cookies[cookie["domain"]][cookie["name"]] ?
        @cookies[cookie["domain"]][cookie["name"]].delete : nil
    else
      @cookies[cookie["domain"]][cookie["name"]] = cookie["value"]
    end
  end

  def cookies(host)
    cooks = @cookies[host] || {}

    # check for domain cookies
    @cookies.keys.each do |dom|
      if dom.length < host.length &&
      dom == host[host.length - dom.length .. host.length - 1]
        dputs "adding domain keys from #{dom}"
        cooks = cooks.merge @cookies[dom]
      end
    end

    if cooks
      return cooks.map{|k,v| "#{k}=#{v};" }.join(" ")
    else
      return ""
    end
  end

  def fetch(uri, method = :get, fields = nil, raw_post_data = nil,
  headers = {}, attachments = {}, limit = 10)
    if limit <= 0
      raise ArgumentError, "HTTP redirection too deep"
    end

    if !uri.is_a?(URI)
      uri = URI.parse(uri)
    end
    host = nil
    ip = nil
    method = method.to_s.downcase.to_sym
    @json = nil

    if self.keep_alive && (host = self.find_keep_alive_for(uri.host))
      dputs "using cached keep-alive connection to #{uri.host}"
    else
      if @use_custom_resolver
        # we'll manually resolve the ip so we can verify it's not local
        tip = nil
        ips = @resolve_cache[uri.host]
        if !ips || !ips.any?
          begin
            Timeout.timeout(MAX_DNS_TIME) do
              ips = [ Addrinfo.ip(uri.host).ip_address ]

              if !ips.any?
                raise
              end

              @resolve_cache[uri.host] = ips
            end
          rescue Timeout::Error
            raise "couldn't resolve #{uri.host} (DNS timeout)"
          rescue SocketError, StandardError => e
            raise "couldn't resolve #{uri.host} (#{e.inspect}) " <<
              "(#{ips.inspect}) {#{tip.inspect})"
          end
        end

        # pick a random one
        tip = ips[rand(ips.length)]
        ip = IPAddr.new(tip)

        if !ip
          raise "couldn't resolve #{uri.host}"
        end

        if @avoid_badnets &&
        BAD_NETS.select{|n| IPAddr.new(n).include?(ip) }.any?
          raise "refusing to talk to IP #{ip.to_s}"
        end

        host = Net::HTTP.new(ip.to_s, uri.port)

        if uri.scheme == "https"
          # openssl needs to know the hostname, so we'll override conn_address
          # to connect to our ip
          host.address = uri.host
          host.custom_conn_address = ip.to_s
        end
      else
        host = Net::HTTP.new(uri.host, uri.port)
      end

      if host.respond_to?(:local_host) && self.local_ip
        host.local_host = self.local_ip
      end

      if self.debug
        host.set_debug_output STDOUT
      end

      if uri.scheme == "https"
        host.use_ssl = true
        host.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
    end

    # convert post params into query params for get requests
    if method == :get
      if raw_post_data
        uri.query = URI.encode(raw_post_data)
        if !headers["Content-Type"]
          headers["Content-Type"] = "application/x-www-form-urlencoded"
        end
      elsif fields && fields.any?
        uri.query = encode_fields(fields)
      end
    end

    if method != :get
      if raw_post_data && attachments.any?
        raise "can't do raw POST data and attachments"
      end

      if attachments.any?
        boundary = "----------#{SecureRandom.hex}"

        headers["Content-Type"] = "multipart/form-data; boundary=#{boundary}"

        post_data = fields.map{|k,v|
          "--#{boundary}\r\n" +
          "Content-Disposition: form-data; name=\"#{k}\"\r\n" +
          "\r\n" +
          v.to_s +
          "\r\n"
        }.join

				post_data = post_data.force_encoding("binary")

        attachments.each do |k,v|
          if !v.is_a?(Hash)
            raise "attachment #{k} is not a hash"
          elsif !v.include?(:data)
            raise "attachment #{k} has no :data"
          end

          post_data << ("--#{boundary}\r\n" <<
            "Content-Disposition: form-data; name=\"#{k}\"; filename=\"" <<
              "#{v[:filename]}\"\r\n" <<
            "Content-Type: #{v[:content_type]}\r\n" <<
            "\r\n").force_encoding("binary")

          post_data << v[:data].force_encoding("binary")
          post_data << "\r\n".force_encoding("binary")
        end

        post_data << ("--#{boundary}--\r\n").force_encoding("binary")

        post_data = post_data.force_encoding("binary")
      elsif raw_post_data
        post_data = raw_post_data
        if !headers["Content-Type"]
          headers["Content-Type"] = "application/x-www-form-urlencoded"
        end
      elsif fields && fields.any?
        post_data = encode_fields(fields)
      else
        post_data = ""
      end

      headers["Content-Length"] = post_data.bytesize.to_s
    end

    if uri.path.to_s == ""
      uri.path = "/"
    end

    uri.path = uri.path.gsub(/^\/\/+/, "/")

    cooks = cookies(uri.host).to_s

    dputs "fetching #{uri} (#{ip.to_s}) " + (uri.user ? "with http auth " +
      uri.user + "/" + ("*" * uri.password.length) + " " : "") +
      "by #{method} with cookies #{cooks}" +
      (attachments.any? ? " with #{attachments.length} attachment(s)" : "")

    hs = {
      "Host" => uri.host,
      "User-Agent" => self.user_agent,
    }

    if cooks != ""
      hs["Cookie"] = cooks
    end

    headers = hs.merge(headers || {})

    if self.keep_alive
      headers["Connection"] = "keep-alive"
      host.skip_close = true
    end

    if uri.user
      headers["Authorization"] = "Basic " +
        ["#{uri.user}:#{uri.password}"].pack("m").delete("\r\n")
    end

    res = nil
    begin
      path = uri.path
      if uri.query.to_s != ""
        path += "?" + uri.query
      end

      Timeout.timeout(@timeout) do
        req = case method
        when :delete
          Net::HTTP::Delete.new(path, headers)
        when :get
          Net::HTTP::Get.new(path, headers)
        when :options
          Net::HTTP::Options.new(path, headers)
        when :post
          Net::HTTP::Post.new(path, headers)
        when :put
          Net::HTTP::Put.new(path, headers)
        else
          raise "unsupported method #{method}"
        end

        if post_data
          req.body = post_data
        end

        res = host.request(req)
      end
    rescue EOFError, Errno::EBADF => e
      if self.keep_alive && self.find_keep_alive_for(uri.host)
        # tried to re-use a dead connection, retry again from the start
        self.save_keep_alive(uri.host, nil)
        dputs "got eof using dead keep-alive socket, retrying"
        return fetch(uri, method, fields, raw_post_data, headers, attachments,
          limit - 1)
      else
        raise e
      end
    end

    if res.get_fields("Set-Cookie")
      res.get_fields("Set-Cookie").each do |cook|
        set_cookie(uri.host, cook)
      end
    end

    if self.keep_alive
      self.save_keep_alive(uri.host, host)
    end

    self.close_stale_keep_alives

    case res
    when Net::HTTPRedirection
      if @follow_redirection
        # follow
        newuri = URI.parse(res["location"])
        if newuri.host
          dputs "following redirection to " + res["location"]
        else
          # relative path
          newuri.host = uri.host
          newuri.scheme = uri.scheme
          newuri.port = uri.port
          newuri.path = "/#{newuri.path}"

          dputs "following relative redirection to " + newuri.to_s
        end

        fetch(newuri.to_s, "get", nil, nil, {}, {}, limit - 1)
      else
        dputs "not following redirection (disabled)"
        return SpongeResponse.new(res, uri)
      end
    else
      return SpongeResponse.new(res, uri)
    end
  end

  def get(uri, params = {}, headers = {})
    fetch(uri, :get, params, nil, headers)
  end

  def post(uri, fields, headers = {})
    fetch(uri, :post, fields, nil, headers)
  end

private
  def dputs(string)
    if self.debug
      puts string
    end
  end

  def encode_fields(fields)
    e = []
    fields.each do |k,v|
      if v.is_a?(Hash)
        # :user => { :name => "hi", :age => "1" }
        # becomes
        # user[hame]=hi and user[age]=1
        v.each do |vk,vv|
          e.push "#{CGI.escape("#{k}[#{vk}]")}=#{CGI.escape(vv.to_s)}"
        end
      elsif v.is_a?(Array)
        # :user => [ "one", "two" ]
        # becomes
        # user[]=one and user[]=two
        v.each do |vv|
          e.push "#{CGI.escape("#{k}[]")}=#{CGI.escape(vv.to_s)}"
        end
      else
        e.push "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"
      end
    end

    e.join("&")
  end
end
