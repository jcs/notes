class WebFinger
  PROFILE_PAGE = "http://webfinger.net/rel/profile-page"

  def self.finger_account(addr)
    m = addr.match(/\A@?([^@]+)@([^@]+)\z/)
    if !m || m[2].to_s == ""
      return nil, "bogus webfinger addr #{addr.inspect}"
    end

    uri = "https://#{m[2]}/.well-known/webfinger?resource=acct:" +
      CGI.escape("#{m[1]}@#{m[2]}")

    begin
      res = ActivityStream.sponge.fetch(uri, :get)
      if !res.ok?
        return nil, "bad status #{res.status}"
      end

      return res.json, nil

    rescue => e
      return nil, "failed webfingering #{uri.inspect}: #{e.message}"
    end
  end
end
