class HTTPSignature
  EXPIRATION_WINDOW = 12.hours

  def self.sign_headers(uri, method, content, key_id, private_key)
    digest = "SHA-256=" + Base64.strict_encode64(
      OpenSSL::Digest::SHA256.new(content).digest)

    date = Time.now.utc
    hdate = date.httpdate
    data = [
      "(request-target): #{method.to_s.downcase} #{uri.path}",
      "host: #{uri.host}",
      "date: #{hdate}",
      "digest: #{digest}",
    ].join("\n")

    rkey = OpenSSL::PKey::RSA.new(private_key)
    signature = Base64.strict_encode64(rkey.sign(
      OpenSSL::Digest::SHA256.new, data))
    header = [
      "keyId=\"#{key_id}\"",
      "algorithm=\"rsa-sha256\"",
      "headers=\"(request-target) host date digest\"",
      "signature=\"#{signature}\"",
    ].join(",")

    return {
      "Signature" => header,
      "Date" => hdate,
      "Digest" => digest,
    }
  end

  def self.signature_components_from(request, enforce_time: true)
    sig = request.env["HTTP_SIGNATURE"]
    if sig.to_s == ""
      return nil, "no signature"
    end

    comps = {}
    sig.split(",").each do |p|
      k, v = p.split("=", 2)
      if comps[k]
        return nil, "duplicate value for #{k} (#{comps[k].inspect} and " <<
          "#{v.inspect})"
      end

      if v.first == "\""
        v = v[1 .. -1]
      end
      if v.last == "\""
        v = v[0 .. -2]
      end

      comps[k] = v
    end

    if comps["keyId"].to_s == ""
      return nil, "no keyId"
    end

    if ![ "rsa-sha256", "hs2019" ].include?(comps["algorithm"].to_s)
      return nil, "unsupported algorithm #{comps["algorithm"].inspect}"
    end

    date = request.env["HTTP_DATE"]
    if date.to_s == ""
      return nil, "no date header"
    end

    udate = DateTime.parse(date).utc
    if enforce_time && Time.now - udate > EXPIRATION_WINDOW
      return nil, "date #{udate} outside expiration window"
    end

    payload = comps["headers"].split(" ").map{|h|
      v = nil
      if h == "(request-target)"
        v = "#{request.env["REQUEST_METHOD"].downcase} #{request.path}"
      elsif h == "content-type"
        v = request.env["CONTENT_TYPE"]
      elsif h == "content-length"
        v = request.env["CONTENT_LENGTH"]
      else
        v = request.env["HTTP_#{h.upcase}"]
      end

      if !v
        return nil, "no header #{h.inspect} to gather into signature"
      end

      "#{h}: #{v}"
    }.join("\n")

    if payload == ""
      return nil, "no headers to sign"
    end

    comps["payload"] = payload

    if comps["signature"].to_s == ""
      return nil, "no signature component in signature header"
    end

    return comps, nil

  rescue => e
    return nil, "verification failure: #{e.message}"
  end

  def self.signature_verified?(components, key_pem)
    sig_raw = Base64.strict_decode64(components["signature"])

    case components["algorithm"]
    when "rsa-sha256", "hs2019"
      rkey = OpenSSL::PKey::RSA.new(key_pem)
      if !rkey.verify(OpenSSL::Digest.new("SHA256"), sig_raw,
      components["payload"])
        return false, "public key verification failed"
      end

      return true, nil
    end

    return false, "unsupported algorithm #{components["algorithm"]}"

  rescue => e
    return false, "failed verifying HTTP signature: #{e.message}"
  end
end
