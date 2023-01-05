class WebFinger
  PROFILE_PAGE = "http://webfinger.net/rel/profile-page"

  def self.webfinger_url_for(addr)
    parts, err = self.addr_parts(addr)
    if !parts
      return nil, err
    end

    url = nil

    begin
      res = ActivityStream.fetch(uri:
        "https://#{parts[:domain]}/.well-known/host-meta", method: :get)
      if res.ok?
        doc = Nokogiri::XML(res.body)
        template = doc.css("Link[rel='lrdd']")[0].attributes["template"].value
        if template.present?
          url = template
        end
      end
    rescue StandardError, Timeout::Error
    end

    if !url
      url = "https://#{parts[:domain]}/.well-known/webfinger?resource={uri}"
    end

    url.gsub!("{uri}", CGI.escape("acct:#{parts[:username]}@#{parts[:domain]}"))
    return url, nil
  end

  def self.finger(addr)
    url, err = WebFinger.webfinger_url_for(addr)
    if !url
      return nil, "failed getting webfinger url for #{addr.inspect}: #{err}"
    end

    begin
      res = ActivityStream.fetch(uri: url, method: :get)
      if !res.ok?
        return nil, "bad status #{res.status}"
      end

      return res.json, nil

    rescue StandardError, Timeout::Error => e
      return nil, "failed webfingering #{url.inspect}: #{e.message}"
    end
  end

private
  def self.addr_parts(addr)
    m = addr.match(/\A@?([^@]+)@([^@]+)\z/)
    if !m || m[2].to_s == ""
      return nil, "bogus addr #{addr.inspect}"
    end

    return { :username => m[1], :domain => m[2] }, nil
  end
end
