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
    ld, err = ActivityStream.get_json_ld(actor)
    if !ld
      return nil, err
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

    ActivityStream.fetch(uri: ld["inbox"], method: :post, body: msg.to_json,
      signer: self)

    return true, nil
  end

  def activitystream_dislike_note!(note)
    like = self.likes.where(:note_id => note.id).first
    if !like
      return
    end

    like.destroy!

    q = QueueEntry.new
    q.action = :signed_post
    q.user_id = self.id
    q.contact_id = note.contact_id
    q.object = {
      "@context" => ActivityStream::NS,
      "id" => "#{self.activitystream_actor}#like-#{Time.now.to_i}",
      "type" => "Undo",
      "actor" => self.activitystream_actor,
      "to" => [ ActivityStream::PUBLIC_URI ],
      "object" => {
        "@context" => ActivityStream::NS,
        "id" => note.public_id,
        "type" => "Like",
      },
      "published" => self.updated_at.utc.iso8601,
    }
    q.save!

    return true, nil
  end

  def activitystream_follow!(actor)
    contact, err = Contact.refresh_for_actor(actor)
    if !contact
      return nil, err
    end

    msg = {
      "@context" => ActivityStream::NS,
      "id" => "#{self.activitystream_actor}#follow-#{Time.now.to_f}",
      "type" => "Follow",
      "actor" => self.activitystream_actor,
      "object" => contact.actor,
    }

    ActivityStream.fetch(uri: contact.inbox, method: :post, body: msg.to_json,
      signer: self)

    following = nil
    begin
      following = self.followings.where(:contact_id => contact.id).first
      if !following
        following = self.followings.build
      end
      following.contact_id = contact.id
      following.follow_object = msg
      following.save!
    rescue ActiveRecord::RecordNotUnique
    end

    return true, nil
  end

  def activitystream_gain_follower!(contact, object)
    # queue up a reply accepting the object
    q = QueueEntry.new
    q.action = :signed_post
    q.user_id = self.id
    q.contact_id = contact.id
    q.object = {
      "@context" => ActivityStream::NS,
      "id" => "#{self.activitystream_actor}#accept-follow-#{Time.now.to_f}",
      "type" => "Accept",
      "actor" => self.activitystream_actor,
      "to" => contact.actor,
      "object" => object,
    }
    q.save!

    follower = nil
    begin
      follower = self.followers.where(:contact_id => contact.id).first
      if !follower
        follower = self.followers.build
      end
      follower.contact_id = contact.id
      follower.follow_object = object
      follower.save!

      App.logger.info "#{self.username} gained follower #{contact.actor}"
    rescue ActiveRecord::RecordNotUnique
    end

    return true, nil
  end

  def activitystream_like_note!(note)
    if self.likes.where(:note_id => note.id).any?
      return
    end

    l = note.likes.build
    l.contact_id = self.contact.id
    l.save!

    q = QueueEntry.new
    q.action = :signed_post
    q.user_id = self.id
    q.contact_id = note.contact_id
    q.object = {
      "@context" => ActivityStream::NS,
      "id" => "#{self.activitystream_actor}#like-#{Time.now.to_i}",
      "type" => "Like",
      "actor" => self.activitystream_actor,
      "to" => [ ActivityStream::PUBLIC_URI ],
      "object" => {
        "@context" => ActivityStream::NS,
        "id" => note.public_id,
      },
      "published" => self.updated_at.utc.iso8601,
    }
    q.save!

    return true, nil
  end

  def activitystream_ping_followers!

    self.followers.includes(:contact).each do |follower|
      q = QueueEntry.new
      q.action = :signed_post
      q.user_id = self.id
      q.contact_id = follower.contact_id
      q.object = {
        "@context" => ActivityStream::NS,
        "id" => "#{self.activitystream_actor}#update-#{Time.now.to_i}",
        "type" => "Update",
        "actor" => self.activitystream_actor,
        "to" => [ ActivityStream::PUBLIC_URI ],
        "object" => self.activitystream_object,
        "published" => self.updated_at.utc.iso8601,
      }
      q.save!
    end

    return true, nil
  end

  def activitystream_object
    ret = {
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

    if self.contact.avatar
      ret.merge!({
        "icon" => {
          "mediaType" => self.contact.avatar.type,
          "type" => "Image",
          "url": self.contact.avatar_url,
        },
      })
    end

    if self.contact.header
      ret.merge!({
        "image" => {
          "mediaType" => self.contact.header.type,
          "type" => "Image",
          "url": self.contact.header_url,
        },
      })
    end

    ret
  end
end
