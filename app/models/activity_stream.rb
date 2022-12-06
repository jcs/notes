class ActivityStream
  NS = "https://www.w3.org/ns/activitystreams"
  NS_SECURITY = "https://w3id.org/security/v1"
  PROFILE_TYPE = "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\""
  ACTIVITY_TYPE = "application/activity+json"
  ACTIVITY_TYPES = [ ACTIVITY_TYPE, "application/ld+json" ]

  PUBLIC_URI = "https://www.w3.org/ns/activitystreams#Public"

  cattr_accessor :debug

  def self.fetch(uri:, method:, post_fields: nil, body: nil,
  headers: {}, attachments: {}, signer: nil, limit: 10)
    if !uri.is_a?(URI)
      uri = URI.parse(uri)
    end

    if !signer
      signer = ActivityStream.request_signer
    end

    hs = HTTPSignature.sign_headers(uri, method, body.to_s,
      signer.contact.key_id, signer.private_key)

    if ActivityStream.debug
      App.logger.info "doing signed #{method} to #{uri}"
    end

    # manually follow redirections because we have to re-sign each request
    self.sponge.follow_redirection = false
    self.sponge.debug = ActivityStream.debug

    res = self.sponge.fetch(uri, method, post_fields, body, headers.merge(hs),
      attachments, limit)

    if (300 .. 399).include?(res.status) && res.headers["Location"].present?
      # follow
      newuri = URI.parse(res.headers["Location"])
      if !newuri.host
        # relative path
        newuri.host = uri.host
        newuri.scheme = uri.scheme
        newuri.port = uri.port
        newuri.path = "/#{newuri.path}"
      end
      if ActivityStream.debug
        App.logger.info "following redirection to #{newuri.to_s}"
      end

      return self.fetch(uri: newuri, method: method, post_fields: post_fields,
        body: body, headers: headers, attachments: attachments, signer: signer,
        limit: limit - 1)
    end

    return res
  end

  def self.get_json(url)
    res = ActivityStream.fetch(uri: url, method: :get, headers: {
      "Accept" => ACTIVITY_TYPE })
    if !res.ok?
      return nil, "failed fetching #{url} (#{res.status}): #{res.body.to_s}"
    end

    return res.json, nil
  end

  def self.get_json_ld(actor)
    endpoint = nil

    if actor.starts_with?("https://")
      endpoint = URI.parse(actor)
      endpoint.fragment = nil
      endpoint = endpoint.to_s
    else
      wf, err = WebFinger.finger(actor)
      if !wf
        return nil, err
      end

      begin
        endpoint = wf["links"].select{|l|
          l["rel"] == "self" && l["type"].starts_with?(ACTIVITY_TYPE)
        }.first["href"]
      rescue
      end

      if endpoint.to_s == ""
        return nil, "failed finding activity JSON URL in #{wf.inspect}"
      end
    end

    json, err = ActivityStream.get_json(endpoint)
    if json == nil
      return nil, err
    end

    context = json["@context"]
    if !context.is_a?(Array)
      context = [ context ]
    end

    if !context.include?(NS)
      return nil, "invalid @context"
    end

    if !json["publicKey"] || !json["publicKey"]["id"] ||
    !json["publicKey"]["publicKeyPem"].to_s.match(/BEGIN PUBLIC KEY/)
      return nil, "no publicKey"
    end

    return json, nil

  rescue => e
    return nil, "failed fetching endpoint for #{actor.inspect}: #{e.message}"
  end

  def self.is_for_request?(request)
    ActivityStream::ACTIVITY_TYPES.include?(request.accept[0].to_s)
  end

  def self.request_signer
    @@signer ||= User.includes(:contact).first
  end

  def self.verified_message_from(request)
    comps, err = HTTPSignature.signature_components_from(request)
    if !comps
      return nil, err
    end

    body = request.body.read
    js = JSON.parse(body)

    cont = Contact.where(:key_id => comps["keyId"]).first
    if !cont
      if js["type"] == "Delete"
        # don't bother fetching actors for user deletion requests
        return nil, "no contact with key id #{comps["keyId"].inspect}, " <<
          "ignoring for Delete"
      end

      # assume the keyid will point to the actor url, maybe with some fragment

      # try to fetch it within a second so we can process this request,
      # otherwise we'll have to queue it up and wait for a retry of this
      # request
      begin
        Timeout.timeout(1.5) do
          Contact.refresh_for_actor(comps["keyId"], nil, false)
        end
      rescue Timeout::Error
      end

      # schedule a full refresh of this actor to fetch their avatar
      Contact.queue_refresh_for_actor!(comps["keyId"])

      cont = Contact.where(:key_id => comps["keyId"]).first
      if !cont
        return nil, "no contact with key id #{comps["keyId"].inspect}"
      end
    end

    ret, err = HTTPSignature.signature_verified?(comps, cont.key_pem)
    if !ret
      return nil, "signature not verified for contact #{cont.actor} key: #{err}"
    end

    if js["actor"] != cont.actor
      ocont = Contact.where(:actor => js["actor"]).first
      if !ocont
        begin
          Timeout.timeout(1.5) do
            Contact.refresh_for_actor(js["actor"], nil, false)
          end
        rescue Timeout::Error
        end

        # schedule a full refresh of this actor to fetch their avatar
        Contact.queue_refresh_for_actor!(js["actor"])

        ocont = Contact.where(:actor => js["actor"]).first
      end

      if !ocont
        return nil, "LD actor #{js["actor"].inspect} != #{cont.actor}"
      end

      # TODO: we need to verify the in-band signature for this forwarded
      # message/reply:
      # https://gist.github.com/marnanel/ba6cba944d1f12d705891b1f7a7808d6
      # for now, just assume everyone is being nice
      cont = ocont
    end

    return ActivityStreamVerifiedMessage.new(cont, js), nil

  rescue => e
    return nil, "failed verifying HTTP signature: #{e.message}"
  end

private
  def self.sponge
    @@sponge ||= Sponge.new
    @@sponge.debug = ActivityStream.debug
    @@sponge.user_agent = "#{App.domain}-notes/1.0"
    @@sponge.keep_alive = true
    @@sponge
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
