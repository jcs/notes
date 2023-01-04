require_relative "spec_helper.rb"

describe HTTPSignature do
  URL = "https://jcs.org/notes/inbox"

  RSA_SHA256_PARAMS = {
    "CONTENT_LENGTH" => "3762",
    "CONTENT_TYPE" => "application/activity+json",
    "HTTP_DATE" => "Wed, 04 Jan 2023 21:03:54 GMT",
    "HTTP_DIGEST" => "SHA-256=LufMhSu1diXHGHR73LUgurU4zyLOzP1JZjXqwCPSz6w=",
    "HTTP_HOST" => "jcs.org",
    "HTTP_SIGNATURE" => "keyId=\"https://mastodon.social/users/mntmn#main-key\",algorithm=\"rsa-sha256\",headers=\"(request-target) host date digest content-type\",signature=\"CAdlzeBNDYFNVEkox4dKm/Jix/UF/KQQynFUyYMtj4aOALHOkdPHf2I8VW2PhfB1VnfNcyKspV5dXRlEPiu/hjTIiz8mNT/lZNecLP/hVsmQveZCUoHokelb87PeYiZFkpm1mEPh8rw0v2pbHSriehTSggR5IjRWQ+LPRGbl8IkqG9LXTADYMbazh5CoTpcGdfRAPEHXTw+1uIqm1JlLVZ32YoptsNLyygGS/EWGq5ys6MdUTpjLpnGPTvU1pdjhTfJZwY3y7mXswFzazRFPUUmyL/deFBITuoQljSQK6RUXw5KwXEjKEJ9fRzryG+Rri+4w5tX5IDAOS/IxTHQDAg==\"",
    "REMOTE_ADDR" => "127.0.0.1",
    "REQUEST_METHOD" => "POST",
  }
  RSA_SHA256_KEY_ID = "https://mastodon.social/users/mntmn#main-key"
  RSA_SHA256_PEM = "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAq+w5nCWaI6f5CgxC7HJ1\n8gcuKINA0xC6TGT5MuN9ZIBJ5qn9UDkW2URDErW2xc2LauKnjIZVaW1IXX7t5tcy\nM31AXxAGPwLxQ6JvRO6T0umBg+AwfX6aOPiy9w0mk3yqWRnmcIWaQ0Iqkt0qxmHA\nxh4vlP3JQE0mLpHmGnH+zVqEG1eJQsmzRDkNeIriqjjNt5NWpfayd4+L1UBGHjHX\njC/bGhgZnl/51JULMW3L6nWBy08hGUVh4T0t2ds3e7FIDjh/M9PePu1cjZMbWYTZ\nlRopAYmlO8hJWc6PIQFfTvERf5xGJqCx1neves7O8Rg6jS97ubiuuhuXf1gMFOsK\nVQIDAQAB\n-----END PUBLIC KEY-----\n"

  HS2019_PARAMS = {
    "CONTENT_LENGTH" => "249",
    "CONTENT_TYPE" => "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\"",
    "HTTP_DATE" => "Wed, 04 Jan 2023 21:20:41 GMT",
    "HTTP_DIGEST" => "SHA-256=RXl4F2WcFSXUdgr0tj8KaoN6nlc/3ANvkSCTJ9Q+AZc=",
    "HTTP_HOST" => "jcs.org",
    "HTTP_SIGNATURE" => "keyId=\"https://mammothcirc.us/users/qbit/main-key\",algorithm=\"hs2019\",headers=\"(request-target) host date digest\",signature=\"k8RB4+D+OVppYyzAUi1qLxPWvPg9VcyLX6BKRUwG4FOOMlCTjcvI5PR2zyRS0QBsYjHJQkt8gwspdjnM9Wcsmxnqu4ICijLCtsDs4L5Rod0AxuqaE1gm65nLFFwowz7hOVWw1fR/fHOOKwAgeZByiUdPJTITM0RfjfEp3f1H75mGCLjVS/VzqpdrKy3vHgoyrA4WwGoPZoC5QDustV5QTjGRUBGdIqqiifXYy8s9mhvzG8DcnAPZV0zqXTxpBNZzHndEKr6FmI9YnGZwDq3mDcQ0v+HNqwRW63Wl5POqZ99nxj+j8+sY6TuxqLvhZXq/LN49H2CvSwXbqrYgdDzpQg==\"",
    "REQUEST_METHOD" => "POST",
  }
  HS2019_KEY_ID = "https://mammothcirc.us/users/qbit/main-key"
  HS2019_PEM = "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA3WTYeA4yJ+ki1bg9gTY5\nOuBXcllJSeWDGv/tTkPPpFCbqG03xbrzCVzE+txIQFzrpXXi9FGYTBSmXkMKmfy2\nTqAnvg/2Mv10hY3+8fhDDY0z0lDtkHPG/MaOOscXB4OGpPFUSA0+NNqBdRWHWLGq\nKNgh2WQoQWX9ReeRMpPKY0ciTJae9niJMCzgpCQX85Xl+FzLk5P6flyOBhXFsRPm\n6AfksZmPvUUAWAtfeL6l8F+/aWletKRaLhmtapBFW3k3mCsxrDwm5KE41d6CRcgz\nUq9MAYtSLs7tqoTcIK9mvzoJivrNJcQAuTGLbZkXGIHBBkthvdESkJv0uBgHZkNb\n/QIDAQAB\n-----END PUBLIC KEY-----\n"

  it "verifies rsa-sha256 signatures" do
    req = Rack::Request.new(Rack::MockRequest.env_for(URL, RSA_SHA256_PARAMS))

    comps, err = HTTPSignature.signature_components_from(req,
      enforce_time: true)
    assert_nil err
    assert comps["keyId"] == RSA_SHA256_KEY_ID
    assert comps["algorithm"] == "rsa-sha256"

    verified, err = HTTPSignature.signature_verified?(comps, RSA_SHA256_PEM)
    assert err == nil
    assert verified == true
  end

  it "fails bogus signatures - header value mismatch" do
    params = RSA_SHA256_PARAMS.dup
    params["CONTENT_TYPE"] += "a"

    req = Rack::Request.new(Rack::MockRequest.env_for(URL, RSA_SHA256_PARAMS))

    comps, err = HTTPSignature.signature_components_from(req,
      enforce_time: true)
    assert err == nil
    assert comps["keyId"] == RSA_SHA256_KEY_ID
    assert comps["algorithm"] == "rsa-sha256"

    verified, err = HTTPSignature.signature_verified?(comps,
      RSA_SHA256_PEM.gsub("3", "4"))
    assert err != nil
    assert verified == false
  end

  it "fails bogus signatures - wrong key" do
    req = Rack::Request.new(Rack::MockRequest.env_for(URL, RSA_SHA256_PARAMS))

    comps, err = HTTPSignature.signature_components_from(req,
      enforce_time: true)
    assert err == nil
    assert comps["keyId"] == RSA_SHA256_KEY_ID
    assert comps["algorithm"] == "rsa-sha256"

    verified, err = HTTPSignature.signature_verified?(comps,
      RSA_SHA256_PEM.gsub("3", "4"))
    assert err != nil
    assert verified == false
  end


  it "verifies hs2019 signatures" do
    req = Rack::Request.new(Rack::MockRequest.env_for(URL, HS2019_PARAMS))

    comps, err = HTTPSignature.signature_components_from(req,
      enforce_time: true)
    assert err == nil
    assert comps["keyId"] == HS2019_KEY_ID
    assert comps["algorithm"] == "hs2019"

    verified, err = HTTPSignature.signature_verified?(comps, HS2019_PEM)
    assert err == nil
    assert verified == true
  end
end
