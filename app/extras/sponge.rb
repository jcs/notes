require "cgi"
require "uri"
require "net/https"
require "resolv"
require "ipaddr"
require "securerandom"
require "stringio"

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

class SpongeError < StandardError; end
class SpongeDNSError < StandardError; end
class SpongeConnectError < StandardError; end
class SpongeTimeoutError < StandardError; end
class SpongeTLSError < StandardError; end
class SpongeRedirectError < StandardError; end

class Sponge
  MAX_TIME = 60
  MAX_DNS_TIME = 10

  # options
  attr_accessor :debug, :follow_redirection, :use_custom_resolver,
    :keep_alive, :timeout, :use_private_keepalives, :avoid_badnets, :local_ip,
    :resolve_cache, :user_agent

  # results
  attr_reader :used_keep_alive, :last_status, :last_response,
    :final_permanent_redirection

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
  def self.fetch(url, headers = {}, limit = 10)
    s = Sponge.new
    s.fetch(url, "get", nil, nil, headers, {}, limit)
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
    @used_keep_alive = false
    @user_agent = "sponge/1.0"

    @avoid_badnets = true
    begin
      if defined?(Rails) && Rails.env.development?
        @avoid_badnets = false
      end
    rescue
    end

    @keep_alives = {}
    Thread.current[:sponge_keep_alives] ||= {}
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

  def fetch(url, method = :get, fields = nil, raw_post_data = nil,
  headers = {}, attachments = {}, limit = 10)
    raise SpongeRedirectError, "Too many HTTP redirections" if limit <= 0

    uri = nil
    if url.is_a?(URI)
      uri = url
    else
      uri = URI.parse(url)
    end
    if uri.host == nil
      if url.to_s.match(/\A[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)\z/)
        uri = URI.parse("http://#{url}")
      end
    end

    if uri.host == nil
      raise SpongeError, "invalid/incomplete URL #{url.to_s.inspect}"
    elsif uri.path == ""
      uri.path = "/"
    end

    uri.fragment = nil

    host = nil
    ip = nil
    method = method.to_s.downcase.to_sym
    @used_keep_alive = false

    if self.keep_alive && (host = self.find_keep_alive_for(uri))
      dputs "using cached keep-alive connection to #{uri.host}"
      @used_keep_alive = true
    else
      if self.use_custom_resolver
        # we'll manually resolve the ip so we can verify it's not local
        tip = nil
        ips = self.resolve_cache[uri.host]
        if !ips || !ips.any?
          begin
            Timeout.timeout(MAX_DNS_TIME) do
              ips = [ Addrinfo.ip(uri.host).ip_address ]

              if !ips.any?
                raise SpongeDNSError, "DNS: could not resolve " <<
                  "#{uri.host.inspect}"
              end

              self.resolve_cache[uri.host] = ips
            end
          rescue SocketError, Timeout::Error
            raise SpongeDNSError, "DNS: couldn't resolve #{uri.host}"
          end
        end

        # pick a random one
        tip = ips[rand(ips.length)]
        ip = IPAddr.new(tip)

        if !ip
          raise "DNS: couldn't resolve #{uri.host.inspect} to a usable IP"
        end

        if self.avoid_badnets &&
        BAD_NETS.select{|n| IPAddr.new(n).include?(ip) }.any?
          raise SpongeDNSError, "DNS: refusing to talk to RFC3330 IP #{ip.to_s}"
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
        host.set_debug_output $stdout
      end

      if uri.scheme == "https"
        host.use_ssl = true
        #host.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
    end

    path = (uri.path == "" ? "/" : uri.path)
    if uri.query
      path += "?" + uri.query
    elsif method == :get && raw_post_data
      path += "?" + URI.encode(raw_post_data)
      if !headers["Content-Type"]
        headers["Content-Type"] = "application/x-www-form-urlencoded"
      end
    end

    if method == :post
      if raw_post_data && attachments.any?
        raise "can't do raw POST data and attachments"
      end

      if attachments.any?
        boundary = "----------#{SecureRandom.hex}"

        headers["Content-Type"] = "multipart/form-data; boundary=#{boundary}"

        sio = StringIO.new("")
        sio.binmode
        sio.write fields.map{|k,v|
          "--#{boundary}\r\n" +
          "Content-Disposition: form-data; name=\"#{k}\"\r\n" +
          "\r\n" +
          v.to_s +
          "\r\n"
        }.join

        attachments.each do |k,v|
          if !v.is_a?(Hash)
            raise "attachment #{k} is not a hash"
          elsif !v.include?(:data)
            raise "attachment #{k} has no :data"
          end

          sio.write "--#{boundary}\r\n" +
            "Content-Disposition: form-data; name=\"#{k}\"; filename=\"" +
              "#{v[:filename]}\"\r\n" +
            "Content-Type: #{v[:content_type]}\r\n" +
            "\r\n"

          sio.write v[:data]
          sio.write "\r\n"
        end

        sio.write "--#{boundary}--\r\n"

        sio.seek(0)
        post_data = sio.read

      elsif raw_post_data
        post_data = raw_post_data
        if !headers["Content-Type"]
          headers["Content-Type"] = "application/x-www-form-urlencoded"
        end
      else
        post_data = fields.map{|k,v|
          "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join("&")
      end

      headers["Content-Length"] = post_data.bytesize.to_s
    end

    path.gsub!(/^\/\//, "/")

    cooks = cookies(uri.host).to_s

    dputs "fetching #{url} (#{ip.to_s}) " + (uri.user ? "with http auth " +
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
        ["#{uri.user}:#{uri.password}"].pack('m').delete("\r\n")
    end

    res = nil
    begin
      Timeout.timeout(self.timeout) do
        if method == :post
          res = host.post(path, post_data, headers)
        else
          res = host.get(path, headers)
        end
      end

    rescue EOFError, Errno::EBADF => e
      if self.keep_alive && self.used_keep_alive
        # tried to re-use a dead connection, retry again from the start
        self.save_keep_alive(uri, nil)
        dputs "got eof using dead keep-alive socket, retrying"
        return fetch(url, method, fields, raw_post_data, headers, attachments,
          limit - 1)
      else
        raise e
      end
    rescue Timeout::Error
      raise SpongeTimeoutError, "Timed out fetching from #{uri.host.inspect}"
    end

    if res.get_fields("Set-Cookie")
      res.get_fields("Set-Cookie").each do |cook|
        set_cookie(uri.host, cook)
      end
    end

    @last_response = res
    @last_status = res.code.to_i

    if self.keep_alive
      self.save_keep_alive(uri, host)
    end

    case res.code.to_i
    when 301, 302, 307, 308
      if self.follow_redirection
        begin
          newuri = URI.parse(res["location"])
        rescue URI::InvalidURIError => e
          raise SpongeRedirectError,
            "invalid URI #{res["location"].inspect} following " <<
            "#{res.code} redirection from #{uri.inspect}"
        end

        if newuri.host
          dputs "following redirection to #{res["location"]}"
        else
          # relative path
          newuri.host = uri.host
          newuri.scheme = uri.scheme
          newuri.port = uri.port
          newuri.path = "/#{newuri.path}"

          dputs "following relative redirection to #{newuri.to_s}"
        end

			  # moved permanently, remember it
        if res.code.to_i == 301 &&
			  (limit == 10 || self.final_permanent_redirection)
				  @final_permanent_redirection = newuri.to_s
        end

        fetch(newuri.to_s, "get", nil, nil, {}, {}, limit - 1)
      else
        dputs "not following redirection (disabled)"
        return res.body
      end
    when 304
      # not modified
      return nil

    else
      return res.body
    end
  end

  def get(url)
    fetch(url, :get)
  end

  def post(url, fields)
    fetch(url, :post, fields)
  end

protected
  def keep_alive_key_for(uri)
    "#{uri.scheme}://#{uri.host}"
  end

  def find_keep_alive_for(uri)
    ka = nil

    if self.use_private_keepalives
      ka = @keep_alives[keep_alive_key_for(uri)]
    else
      ka = Thread.current[:sponge_keep_alives][keep_alive_key_for(uri)]
    end

    if ka
      if ka[:time] >= (Time.now - 15)
        return ka[:socket]
      else
        dputs "keep alive too stale, discarding"
      end
    end

    nil
  end

  def save_keep_alive(uri, obj)
    if self.use_private_keepalives
      if obj == nil
        @keep_alives.delete(keep_alive_key_for(uri))
      else
        @keep_alives[keep_alive_key_for(uri)] = {
          :time => Time.now,
          :socket => obj,
        }
      end
    else
      if obj == nil
        Thread.current[:sponge_keep_alives][keep_alive_key_for(uri)] = nil
      else
        Thread.current[:sponge_keep_alives][keep_alive_key_for(uri)] = {
          :time => Time.now,
          :socket => obj,
        }
      end
    end
  end

  def dputs(string)
    if self.debug
      puts string
    end
  end
end
