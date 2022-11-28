module UserActivityStream
  def activitystream_actor
    activitystream_url
  end

  def activitystream_key_id
    "#{activitystream_actor}#key"
  end

  def activitystream_inbox_url
    "#{self.activitystream_url}/inbox"
  end

  def activitystream_outbox_url
    "#{self.activitystream_url}/outbox"
  end

  def activitystream_url
    App.base_url
  end

  # activitystream actions

  def activitystream_delete!(actor)
    ld = ActivityStream.get_json_ld(actor)
    if !ld
      raise "failed to get JSON LD for #{actor}"
    end

    msg = {
      "@context" => ActivityStream::NS,
      "id" => "#{self.activitystream_actor}#delete#{Time.now.to_f}",
      "type" => "Delete",
      "actor" => self.activitystream_actor,
      "to" => [ ActivityStream::PUBLIC_URI ],
      "object" => self.activitystream_actor,
      "published" => Time.now.utc.iso8601,
    }

    ActivityStream.signed_post_with_key(ld["inbox"], msg.to_json,
      self.activitystream_key_id, self.private_key)
  end

  def activitystream_follow!(actor)
    contact = Contact.refresh_for_actor(actor)
    if !contact
      App.logger.error "failed to get contact from update of #{actor.inspect}"
      return
    end

    jmsg = {
      "@context" => ActivityStream::NS,
      "id" => "#{self.activitystream_actor}#follow-#{Time.now.to_f}",
      "type" => "Follow",
      "actor" => self.activitystream_actor,
      "object" => contact.actor,
    }.to_json

    ActivityStream.signed_post_with_key(contact.inbox, jmsg,
      self.activitystream_key_id, self.private_key)

    following = nil
    begin
      following = self.followings.where(:contact_id => contact.id).first
      if !following
        following = self.followings.build
      end
      following.contact_id = contact.id
      following.follow_object = jmsg
      following.save!
    rescue ActiveRecord::RecordNotUnique => e
    end
  end

  def activitystream_gain_follower!(contact, object)
    # queue up a reply accepting the object
    reply = {
      "@context" => ActivityStream::NS,
      "id" => "#{self.activitystream_actor}#accept-follow-#{Time.now.to_f}",
      "type" => "Accept",
      "actor" => self.activitystream_actor,
      "to" => contact.actor,
      "object" => object,
    }

    q = QueueEntry.new
    q.action = :signed_post
    q.user_id = self.id
    q.contact_id = contact.id
    q.object_json = reply.to_json
    q.save!

    follower = nil
    begin
      follower = self.followers.where(:contact_id => contact.id).first
      if !follower
        follower = self.followers.build
      end
      follower.contact_id = contact.id
      follower.follow_object = object.to_json
      follower.save!

      App.logger.info "#{self.username} gained follower #{contact.actor}"
    rescue ActiveRecord::RecordNotUnique => e
    end
  end

  def activitystream_ping_followers!
    msg = {
      "@context" => ActivityStream::NS,
      "id" => "#{self.activitystream_actor}#update-#{Time.now.to_i}",
      "type" => "Update",
      "actor" => self.activitystream_actor,
      "to" => [ ActivityStream::PUBLIC_URI ],
      "object" => self.activitystream_object,
      "published" => self.updated_at.utc.iso8601,
    }.to_json

    self.followers.includes(:contact).each do |follower|
      begin
        ActivityStream.signed_post_with_key(follower.contact.inbox,
          msg, self.activitystream_key_id, self.private_key)
      rescue => e
        App.logger.error "failed updating #{follower.contact.actor}: " <<
          "#{e.message}"
      end
    end

    true
  end

  def activitystream_unfollow!(actor)
    ld = ActivityStream.get_json_ld(actor)
    if !ld
      raise "failed to get JSON LD for #{actor}"
    end

    actor = ld["id"]

    f = self.followings.joins(:contact).where("contacts.actor = ?", actor).first
    msg = {
      "@context" => ActivityStream::NS,
    }
    if f
      msg.merge!({
        "id" => "#{self.activitystream_actor}#undo-follow-#{Time.now.to_f}",
        "type" => "Undo",
        "actor" => self.activitystream_actor,
        "object" => JSON.parse(f.follow_object),
      })
    else
      msg.merge!({
        "id" => "#{self.activitystream_actor}#unfollow-#{Time.now.to_f}",
        "type" => "Unfollow",
        "actor" => self.activitystream_actor,
        "object" => ld["id"],
      })
    end

    ActivityStream.signed_post_with_key(ld["inbox"], msg.to_json,
      self.activitystream_key_id, self.private_key)

    # TODO: only if that was accepted
    f = self.followings.joins(:contact).where("contacts.actor = ?", actor).first
    if f
      f.destroy
    end
  end

  def activitystream_object
    {
      "@context" => [
        ActivityStream::NS,
        ActivityStream::NS_SECURITY,
        "manuallyApprovesFollowers" => "as:manuallyApprovesFollowers",
      ],
      "id" => self.activitystream_url,
      "type": "Person",
      "name" => self.contact.realname,
      "summary" => self.contact.about,
      "published" => self.created_at.utc.iso8601,
      "preferredUsername" => self.username,
      "icon" => (self.contact.avatar ? {
        "mediaType" => self.contact.avatar.type,
        "type" => "Image",
        "url": self.contact.avatar_url,
      } : {}),
      "url" => self.activitystream_url,
      "followers" => "#{self.activitystream_url}/followers",
      "following" => "#{self.activitystream_url}/following",
      "inbox" => self.activitystream_inbox_url,
      "outbox" => self.activitystream_outbox_url,
      "manuallyApprovesFollowers" => false,
      "discoverable" => true,
      "publicKey" => {
        "id" => self.activitystream_key_id,
        "owner" => self.activitystream_actor,
        "publicKeyPem" => self.contact.key_pem,
      },
      "attachment" => [
        {
          "type" => "PropertyValue",
          "name" => "web",
          # XXX TODO: move to user table
          "value" => "<a href=\"https://#{App.domain}/\" target=\"_blank\" " +
            "rel=\"nofollow noopener noreferrer me\">" +
            "https://#{App.domain}/</a>",
        },
      ],
    }
  end

  def activitystream_signed_post_to_contact(contact, json)
    ActivityStream.signed_post_with_key(contact.inbox_uri, json,
      self.activitystream_key_id, self.private_key)
  end
end
