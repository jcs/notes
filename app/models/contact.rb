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
    self.refresh_for_actor(qe.object["actor"])
  end

  def self.refresh_for_actor(actor, person_ld = nil)
    if (c = Contact.where(:actor => actor).first) && c.recently_refreshed?
      return c
    end

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
      contact.last_refreshed_at = Time.now
      contact.save!
    rescue ActiveRecord::RecordNotUnique => e
      if retried
        raise e
      end
      retry
    end

    if contact && person_ld["icon"].try(:[], "type") == "Image" &&
    person_ld["icon"]["url"].present?
      qe = QueueEntry.new
      qe.contact_id = contact.id
      qe.action = :contact_update_avatar
      qe.save!
    end

    return contact, nil
  end

  def self.refresh_for_actor_with_timeout(actor, timeout = 1.5)
    begin
      Timeout.timeout(timeout) do
        return Contact.refresh_for_actor(actor)
      end
    rescue Timeout::Error
    end

    return nil, "timed out"
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

  def ingest_recent_notes!
    if self.local?
      return nil, "is local"
    end

    if self.recently_refreshed?
      return nil, "recently refreshed"
    end

    ref, err = self.refresh!
    if !ref
      return nil, err
    end

    if !self.object["outbox"].present?
      return nil, "no outbox present in LD"
    end

    outbox, err = ActivityStream.get_json(self.object["outbox"])
    if outbox == nil
      return nil, "fetch of outbox failed: #{err}"
    end

    if !outbox["first"].present?
      return nil, "outbox has no first item"
    end

    items, err = ActivityStream.get_json(outbox["first"])
    if items == nil
      return nil, "fetch of first page at #{outbox["first"]} failed: #{err}"
    end

    if !items["orderedItems"].is_a?(Array)
      return nil, "outbox items does not have an array for orderedItems"
    end

    # newest should be first
    ingested = 0
    items["orderedItems"][0, 20].reverse.each do |i|
      if i["object"].try(:[], "type") != "Note"
        next
      end

      asvm = ActivityStreamVerifiedMessage.new(self, i)
      if asvm
        Note.ingest_note!(asvm)
        ingested += 1
      end
    end

    return ingested, nil
  end

  def linkified_about(opts = {})
    html, mentions = HTMLSanitizer.linkify_with_mentions(about, opts)
    html
  end

  def local?
    self.user_id.present?
  end

  def move_to!(new_actor)
    self.transaction do
      other_c = Contact.where(:actor => new_actor).first
      if other_c
        other_c.notes.each do |n|
          n.update_column(:contact_id, self.id)
        end
        other_c.destroy!
      end
      self.actor = new_actor
      self.save!
      Contact.queue_refresh_for_actor!(new_actor)
    end
  end

  def realname_or_address
    self.realname.to_s == "" ? self.address : self.realname
  end

  def recently_refreshed?
    self.last_refreshed_at != nil && (Time.now - self.last_refreshed_at) <
      (60 * 5)
  end

  def refresh!
    Contact.refresh_for_actor(self.actor)
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

  def update_avatar!
    if self.object["icon"] && self.object["icon"]["type"] == "Image" &&
    self.object["icon"]["url"].to_s != ""
      av, err = Attachment.build_from_url(self.object["icon"]["url"])
      if !av
        return nil, "failed fetching #{self.object["icon"]["url"]}: #{err}"
      end
      if self.avatar
        self.avatar.destroy
      end
      self.avatar = av
      self.save!
    elsif self.avatar
      self.avatar.destroy
      self.avatar_attachment_id = nil
      self.save!
    end

    return true, nil
  end

  def url_or_locate_url
    self.url.to_s == "" ?
      "#{LocatorController.path}/#{CGI.escape(self.address)}" : self.url
  end

  def username
    self.address.split("@").first
  end
end
