class ActivityStream
  NS = "https://www.w3.org/ns/activitystreams"
  NS_SECURITY = "https://w3id.org/security/v1"
  PROFILE_TYPE = "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\""
  ACTIVITY_TYPE = "application/activity+json"
  ACTIVITY_TYPES = [ ACTIVITY_TYPE, "application/ld+json" ]

  PUBLIC_URI = "https://www.w3.org/ns/activitystreams#Public"

  cattr_accessor :debug

  def self.sponge
    @@sponge ||= Sponge.new
    @@sponge.debug = ActivityStream.debug
    @@sponge.user_agent = "#{App.domain}-notes/1.0"
    @@sponge.keep_alive = true
    @@sponge
  end

  def self.get_notes(actor)
  end

  def self.get_json_ld(actor)
    endpoint = nil

    if actor.starts_with?("https://")
      endpoint = actor
    else
      wf = WebFinger.finger_account(actor)
      if !wf
        raise "failed to webfinger #{actor.inspect}"
      end

      begin
        endpoint = wf["links"].select{|l|
          l["rel"] == "self" && l["type"].starts_with?(ACTIVITY_TYPE)
        }.first["href"]
      rescue
      end

      if endpoint.to_s == ""
        App.logger.info "failed finding activity JSON URL in #{wf.inspect}"
        return nil
      end
    end

    res = ActivityStream.sponge.fetch(endpoint, :get, nil, nil, {
      "Accept" => ACTIVITY_TYPE })

    if !res.ok?
      raise "fetch of #{endpoint.inspect} failed (#{res.status})"
    end

    context = res.json["@context"]
    if !context.is_a?(Array)
      context = [ context ]
    end

    if !context.include?(NS)
      raise "invalid @context"
    end

    if res.json["id"] != endpoint
      raise "LD id #{res.json["id"].inspect} != endpoint #{endpoint.inspect}"
    end

    if !res.json["publicKey"] || !res.json["publicKey"]["id"] ||
    !res.json["publicKey"]["publicKeyPem"].to_s.match(/BEGIN PUBLIC KEY/)
      raise "no publicKey"
    end

    return res.json

  rescue => e
    App.logger.info "failed fetching endpoint for #{actor.inspect}: " +
      "#{e.message}"
    return nil
  end

  def self.is_for_request?(request)
    ActivityStream::ACTIVITY_TYPES.include?(request.accept[0].to_s)
  end

  def self.signed_post_with_key(url, json, key_id, private_key)
    if !url.is_a?(URI)
      url = URI.parse(url)
    end

    hs = HTTPSignature.sign_headers(url, json, key_id, private_key)

    App.logger.info "doing signed POST to #{url} with #{key_id}"
    if ActivityStream.debug
      App.logger.info "#{json}"
    end

    res = ActivityStream.sponge.fetch(url, :post, nil, json, hs.merge({
      "Content-Type" => ACTIVITY_TYPE
    }))

    if !res.ok?
      App.logger.info "failed with status #{res.status}: " <<
        res.body.to_s[0, 100]
      return false
    end

    true
  end

  def self.verified_message_from(request)
    comps = HTTPSignature.signature_components_from(request)
    if !comps
      return nil
    end

    body = request.body.read
    js = JSON.parse(body)

    cont = Contact.where(:key_id => comps["keyId"]).first
    if !cont
      if js["type"] == "Delete"
        # don't bother fetching actors for user deletion requests
        raise "no contact with key id #{comps["keyId"].inspect}, ignoring " <<
          "for Delete"
      end

      # assume the keyid will point to the actor url, maybe with some fragment,
      # so we'll ingest it from the queue and have it ready for next time
      Contact.queue_refresh_for_actor!(comps["keyId"])
      raise "no contact with key id #{comps["keyId"].inspect}"
    end

    if !HTTPSignature.signature_verified?(comps, cont.key_pem)
      raise "signature not verified for contact #{cont.actor} key"
    end

    if js["actor"] != cont.actor
      raise "LD actor #{js["actor"].inspect} != #{cont.actor}"
    end

    return ActivityStreamVerifiedMessage.new(cont, js)

  rescue => e
    App.logger.info "failed verifying HTTP signature: #{e.message}"
    return nil
  end
end

class ActivityStreamVerifiedMessage
  attr_reader :contact
  attr_reader :message

  def initialize(contact, message)
    @contact = contact
    @message = message

    if !message["@context"].is_a?(Array)
      message["@context"] = [ message["@context"] ]
    end

    if !message["@context"].include?(ActivityStream::NS)
      raise "bogus message context #{message["@context"].inspect}"
    end
  end
end
