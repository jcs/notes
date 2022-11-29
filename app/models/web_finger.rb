class WebFinger
  PROFILE_PAGE = "http://webfinger.net/rel/profile-page"

  def self.finger_account(addr)
    m = addr.match(/\A@?([^@]+)@([^@]+)\z/)
    if !m || m[2].to_s == ""
      App.logger.info "bogus webfinger addr #{addr.inspect}"
      return
    end

    uri = "https://#{m[2]}/.well-known/webfinger?resource=acct:" +
      CGI.escape("#{m[1]}@#{m[2]}")

    begin
      res = ActivityStream.sponge.fetch(uri, :get)
      if !res.ok?
        raise "bad status #{res.status}"
      end
      return res.json

    rescue => e
      App.logger.info "failed webfingering #{uri.inspect}: #{e.message}"
    end

    nil
  end
end
