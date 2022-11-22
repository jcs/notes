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

    js = nil
    begin
      body = ActivityStream.sponge.fetch(uri, :get)
      if !(200 .. 299).include?(ActivityStream.sponge.last_status)
        raise "bad status #{ActivityStream.sponge.last_status}"
      end
      js = JSON.parse(body)
    rescue => e
      App.logger.info "failed webfingering #{uri.inspect}: #{e.message}"
      return
    end

    js
  end
end
