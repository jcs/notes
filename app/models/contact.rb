class Contact < DBModel
  belongs_to :avatar,
    :class_name => "Attachment",
    :foreign_key => "avatar_attachment_id"
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
    q.object_json = { "actor" => actor }.to_json
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
        if contact.user_id
          # refuse refreshing
          return true, nil
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
          av.save!
          contact.avatar_attachment_id = av.id
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

  def inbox_uri
    @_inbox_uri ||= URI.parse(self.inbox)
  end

  def realname_or_address
    self.realname.to_s == "" ? self.address : self.realname
  end

  def refresh!(include_avatar = false)
    Contact.refresh_for_actor(self.actor, nil, include_avatar)
  end

  def url_or_locate_url
    self.url.to_s == "" ?
      "#{LocatorController.path}/#{CGI.escape(self.address)}" : self.url
  end
end
