class Contact < DBModel
  belongs_to :avatar,
    :class_name => "Attachment",
    :foreign_key => "avatar_attachment_id"
  belongs_to :header,
    :class_name => "Attachment",
    :foreign_key => "header_attachment_id"
  belongs_to :user
  has_many :notes,
    :dependent => :destroy
  has_many :likes,
    :dependent => :destroy
  has_many :forwards,
    :dependent => :destroy

  def self.queue_refresh_for_actor!(actor)
    q = QueueEntry.new
    q.action = :contact_refresh
    q.object = { "actor" => actor }
    q.save!
  end

  def self.refresh_for_queue_entry(qe)
    self.refresh_for_actor(qe.object["actor"], nil, true)
  end

  def self.refresh_for_actor(actor, person_ld = nil, fetch_avatar = false)
    if !person_ld
      if ActivityStream.debug
        App.logger.info "refreshing contact for #{actor.inspect}, fetching LD"
      end
      person_ld, err = ActivityStream.get_json_ld(actor)
      if !person_ld
        return nil, err
      end
    end

    contact = nil
    retried = false
    begin
      contact = Contact.where(:actor => person_ld["id"]).first
      if contact
        if contact.local?
          # refuse refreshing
          return contact, nil
        end
      else
        contact = Contact.new
      end
      domain = URI.parse(person_ld["id"]).host
      contact.actor = person_ld["id"]
      contact.inbox = person_ld["inbox"]
      contact.url = person_ld["url"]
      contact.realname = person_ld["name"]
      contact.about = person_ld["summary"]
      contact.address = "#{person_ld["preferredUsername"]}@#{domain}"
      contact.key_id = person_ld["publicKey"]["id"]
      contact.key_pem = person_ld["publicKey"]["publicKeyPem"]
      contact.object = person_ld
      contact.save!
    rescue ActiveRecord::RecordNotUnique => e
      if retried
        raise e
      end
      retry
    end

    if fetch_avatar
      if person_ld["icon"] && person_ld["icon"]["type"] == "Image" &&
      person_ld["icon"]["url"].to_s != ""
        av, err = Attachment.build_from_url(person_ld["icon"]["url"])
        if av
          if contact.avatar
            contact.avatar.destroy
          end
          contact.avatar = av
          contact.save!
        end
      elsif contact.avatar
        contact.avatar.destroy
        contact.avatar_attachment_id = nil
        contact.save!
        return nil, "[c#{contact.id}] no avatar icon specified but " <<
          "have attachment, deleting it"
      end
    end

    return contact, nil
  end

  def activitystream_get_json_ld
    if !@_asld
      @_asld, err = ActivityStream.get_json_ld(self.actor)
    end
    @_asld
  end

  def actor_uri
    @_actor_uri ||= URI.parse(self.actor)
  end

  def avatar_url
    "#{App.base_url}/avatars/#{self.address}"
  end

  def header_url
    if self.header
      "#{App.base_url}/attachments/#{self.header.id}"
    else
      self.avatar_url
    end
  end

  def inbox_uri
    @_inbox_uri ||= URI.parse(self.inbox)
  end

  def linkified_about(opts = {})
    html, mentions = HTMLSanitizer.linkify_with_mentions(about, opts)
    html
  end

  def local?
    self.user_id.present?
  end

  def realname_or_address
    self.realname.to_s == "" ? self.address : self.realname
  end

  def refresh!(include_avatar = false)
    Contact.refresh_for_actor(self.actor, nil, include_avatar)
  end

  def relationship_object_with(user)
    {
      "id" => self.id,
      "following" => user.followers.where(:contact_id => self.id).any?,
      "showing_reblogs" => true,
      "notifying" => false,
      "followed_by" => user.followings.where(:contact_id => self.id).any?,
      "blocking" => false,
      "blocked_by" => false,
      "muting" => false,
      "muting_notifications" => false,
      "requested" => false,
      "domain_blocking" => false,
      "endorsed" => false,
    }
  end

  def timeline_object
    {
      "id" => self.id.to_s,
      "username" => self.username,
      "acct" => self.address,
      "display_name" => self.realname,
      "locked" => false,
      "bot" => false,
      "note" => self.about,
      "created_at" => self.created_at.utc.iso8601,
      "url" => self.url,
      "avatar" => self.avatar_url,
      "avatar_static" => self.avatar_url,
      # metatext requires urls for these even if they aren't present
      "header" => self.header_url,
      "header_static" => self.header_url,
      "followers_count" => self.local? ? self.user.followers.count : 0,
      "following_count" => self.local? ? self.user.followings.count : 0,
      "statuses_count" => self.local? ? self.notes.count : 0,
      "last_status_at" => self.local? ?
        self.notes.last.try(:created_at).try(:utc).try(:iso8601) : nil,
      "emojis" => [],
      "fields" => [],
    }
  end

  def url_or_locate_url
    self.url.to_s == "" ?
      "#{LocatorController.path}/#{CGI.escape(self.address)}" : self.url
  end

  def username
    self.address.split("@").first
  end
end
