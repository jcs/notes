class Note < DBModel
  belongs_to :contact
  belongs_to :parent_note,
    :class_name => "Note"
  has_many :attachments,
    :dependent => :destroy
  has_one :user,
    :through => :contact
  has_many :likes,
    :dependent => :destroy
  has_many :forwards,
    :dependent => :destroy
  has_many :replies,
    :class_name => "Note",
    :foreign_key => "parent_note_id"

  validates_presence_of :contact

  scope :timeline, -> {
    where(:for_timeline => true).order("created_at DESC")
  }

  before_create :assign_conversation, :assign_ids

  after_create do
    if local? then self.activitystream_publish!("Create") end
  end
  before_destroy do
    if local? then self.activitystream_publish!("Delete") end
  end

  attr_accessor :like_count, :reply_count, :forward_count

  def self.ingest!(asvm)
    if !asvm.is_a?(ActivityStreamVerifiedMessage)
      raise "#{asvm.class} not a ActivityStreamVerifiedMessage"
    end

    note = asvm.message["object"]
    if !note || note["id"].blank?
      return nil, "note has no id"
    end

    dbnote = asvm.contact.notes.where(:public_id => note["id"]).first
    if !dbnote
      dbnote = Note.new
      dbnote.contact_id = asvm.contact.id
      dbnote.public_id = note["id"]
    end
    dbnote.object = note
    dbnote.conversation = note["conversation"]
    dbnote.note = note["content"]

    dbnote.created_at = DateTime.parse(note["published"])
    if dbnote.created_at > Time.now
      # so sorting by created_at works properly
      dbnote.created_at = Time.now
    end

    if note["updated"] && note["updated"] != note["published"]
      dbnote.note_modified_at = DateTime.parse(note["updated"])
    end
    if dbnote.note_modified_at && dbnote.note_modified_at > Time.now
      dbnote.note_modified_at = Time.now
    end

    tos = (note["to"].is_a?(Array) ? note["to"] : [ note["to"] ])
    ccs = (note["cc"].is_a?(Array) ? note["cc"] : [ note["cc"] ])
    dbnote.is_public = tos.include?(ActivityStream::PUBLIC_URI) ||
      ccs.include?(ActivityStream::PUBLIC_URI)

    if dbnote.is_public
      # anything directly mentioning us is for our timeline, or any public
      # chatter that is not a reply to someone else
      # TODO: but if it's chatter between two people we follow, maybe we want
      # to see it
      dbnote.for_timeline = tos.include?(asvm.contact.actor) ||
        ccs.include?(asvm.contact.actor) || !dbnote.directed_at_someone?
    else
      # not public, this is a private message
      dbnote.for_timeline = false
    end

    if note["inReplyTo"].present? &&
    (parent = Note.where(:public_id => note["inReplyTo"]).first)
      dbnote.parent_note_id = parent.id
    end

    dbnote.mentioned_contact_ids = []
    (note["tag"] || []).select{|t| t["type"] == "Mention" }.each do |m|
      if c = Contact.where(:actor => m["href"]).first
        dbnote.mentioned_contact_ids.push c.id
      end
    end
    dbnote.mentioned_contact_ids.uniq!

    dbnote.save!

    # match our attachment list with the note's, deleting or creating as
    # necessary
    have = dbnote.attachments.to_a
    want = dbnote.object["attachment"] || []
    to_fetch = {}
    to_delete = {}

    have.each do |h|
      if !want.select{|a| a["url"] }.include?(h.source)
        to_delete[h.id] = true
      end
    end
    want.each do |obj|
      if !have.select{|a| a.source }.include?(obj["url"])
        to_fetch[obj["url"]] = obj
      end
    end

    if to_delete.any?
      dbnote.attachments.where(:id => to_delete.keys).destroy_all
    end

    to_fetch.each do |u,obj|
      if QueueEntry.where(:note_id => dbnote.id, :object => obj).any?
        next
      end

      qe = QueueEntry.new
      qe.action = :attachment_fetch
      qe.note_id = dbnote.id
      qe.object = obj
      qe.save!
    end

    return dbnote, nil
  end

  def self.ingest_from_url!(url)
    obj, err = ActivityStream.get_json(url)
    if obj == nil
      return nil, err
    end

    c = Contact.where(:actor => obj["attributedTo"]).first
    if !c
      c, err = Contact.refresh_for_actor(obj["attributedTo"])
      if c == nil
        return nil, "failed to get note actor #{obj["attributedTo"]}: #{err}"
      end
    end

    asvm = ActivityStreamVerifiedMessage.new(c, { "object" => obj })
    Note.ingest!(asvm)
  end

  def activitystream_activity_object(verb)
    if !self.user
      return nil
    end

    {
      "@context" => ActivityStream::NS,
      "id" => "#{self.user.activitystream_url}/#{self.id}/activity",
      "type" => verb,
      "actor" => self.user.activitystream_actor,
      "published" => self.created_at.utc.iso8601,
      "to" => [ ActivityStream::PUBLIC_URI ],
      "cc" => [ "#{self.user.activitystream_url}/followers" ],
      "object" => self.activitystream_object,
    }
  end

  def activitystream_object
    if !self.user
      return nil
    end

    to = []
    cc = []
    if self.is_public?
      if self.directed_at_someone?
        mc = self.mentioned_contacts.dup
        to = [ mc.shift.actor ]
        cc = mc.map{|c| c.actor } +
          [ ActivityStream::PUBLIC_URI ]
      else
        to = [ ActivityStream::PUBLIC_URI ]
        cc = [ "#{self.user.activitystream_url}/followers" ] +
          self.mentioned_contacts.map{|c| c.actor }
      end
    else
      to = self.mentioned_contacts.first.actor
    end

    {
      "@context" => ActivityStream::NS,
      "id" => self.public_id,
      "type" => "Note",
      "published" => (self.created_at || Time.now).utc.iso8601,
      "updated" => self.note_modified_at.try(:utc).try(:iso8601),
      "to" => to,
      "cc" => cc,
      "context" => self.conversation,
      "inReplyTo" => self.parent_note.try(:public_id),
      "attributedTo" => self.user.activitystream_actor,
      "content" => self.note,
      "url" => "#{self.user.activitystream_url}/#{self.id}",
      "replies" => {
        "id" => "#{self.user.activitystream_url}/#{self.id}/replies",
        "type" => "Collection",
        "first" => {
          "type" => "CollectionPage",
          "next" => "#{self.user.activitystream_url}/#{self.id}/replies/page/1",
          "partOf" => "#{self.user.activitystream_url}/#{self.id}/replies",
          "items" => [],
        }
      },
      # this doesn't use .order("id") because we may have unsaved built objects
      # and don't want to hit the db
      "attachment" => self.attachments.sort_by{|a| a.id }.map{|a|
        a.activitystream_object
      },
      "tag" => self.mentioned_contacts.map{|c|
        {
          "type" => "Mention",
          "href" => c.actor,
          "name" => "@#{c.address}",
        }
      },
    }
  end

  def activitystream_publish!(verb)
    if !self.local?
      raise "trying to publish a non-local note!"
    end

    aobj = self.activitystream_object
    tos = (aobj["to"] + aobj["cc"]).uniq

    to_contacts = []
    if tos.include?(ActivityStream::PUBLIC_URI)
      to_contacts = self.user.followers.includes(:contact).map{|f| f.contact }
    else
      to_contacts = Contact.where(:actor => tos)
    end

    js = self.activitystream_activity_object(verb)

    to_contacts.each do |c|
      q = QueueEntry.new
      q.action = :signed_post
      q.user_id = self.contact.user.id
      q.contact_id = c.id
      q.note_id = self.id
      q.object = js
      q.save!
    end

    to_contacts.count
  end

  def authoritative_url
    self.local? ? self.url : self.public_id
  end

  def directed_at_someone?
    !!self.plaintext_note.match(/\A@/)
  end

  def forward_by!(contact)
    if !(l = self.forwards.where(:contact_id => contact.id).first)
      l = Forward.new
      l.contact_id = contact.id
      l.note_id = self.id
      l.save!
    end
  end

  def forward_count
    @forward_count ||= self.forwards.count
  end

  def like_by!(contact)
    if !(l = self.likes.where(:contact_id => contact.id).first)
      l = Like.new
      l.contact_id = contact.id
      l.note_id = self.id
      l.save!
    end
  end

  def like_count
    @like_count ||= self.likes.count
  end

  def local?
    self.contact.local?
  end

  def mentioned_contacts
    @mentioned_contacts ||=
      Contact.where(:id => (self.mentioned_contact_ids || [])).to_a
  end

  def plaintext_note
    note.gsub(/<[^>]+>/, "")
  end

  def reply_count
    @reply_count ||= self.replies.count
  end

  def sanitized_html(opts = {})
    @sanitized_html ||= HTMLSanitizer.sanitize(note, opts)
  end

  def thread
    tns = Note.where(:conversation => self.conversation).order(:created_at).to_a
    order = tns.extract!{|n| n.parent_note_id.to_i == 0 } || []
    while tns.any?
      tn = tns.shift

      (order.count - 1).times do |x|
        if order[x].id == tn.parent_note_id
          order.insert(x + 1, tn)
          tn = nil
          break
        end
      end

      if tn
        order.push tn
      end
    end
    order
  end

  def timeline_object_for(user)
    {
      "id" => self.id.to_s,
      "created_at" => self.created_at.try(:utc).try(:iso8601),
      "edited_at" => self.note_modified_at.try(:utc).try(:iso8601),
      "in_reply_to_id" => self.parent_note_id.try(:to_s),
      "in_reply_to_account_id" => self.parent_note_id.present? ?
        self.parent_note.contact_id.to_s : nil,
      "sensitive" => object ? !!object["sensitive"] : false,
      "spoiler_text" => "",
      "visibility" => "public",
      "language" => "en",
      "url" => self.public_id,
      "uri" => self.public_id,
      "replies_count" => self.reply_count,
      "reblogs_count" => self.forward_count,
      "favourites_count" => self.like_count,
      "favourited" => user.likes.where(:note_id => self.id).any?,
      "reblogged" => user.contact.forwards.where(:note_id => self.id).any?,
      #"muted" => false,
      #"bookmarked" => false,
      "content" => self.note,
      "reblog" => nil,
      "media_attachments" => self.attachments.map(&:timeline_object),
      "mentions" => [],
      "tags" => [],
      "emojis" => [],
      "card" => nil,
      "poll" => nil,
      "pinned" => false,
      "account" => self.contact.timeline_object,
    }
  end

  def unforward_by!(contact)
    self.forwards.where(:contact_id => contact.id).destroy_all
  end

  def unlike_by!(contact)
    self.likes.where(:contact_id => contact.id).destroy_all
  end

  def url
    o = [ App.base_url ]
    if !self.contact.user_id
      o.push "from"
      o.push CGI.escapeHTML(self.contact.address)
    end
    o.push self.id
    o.join("/")
  end

private
  def assign_conversation
    if self.conversation.blank? && self.local?
      if self.parent_note
        self.conversation = self.parent_note.conversation
      else
        self.conversation = "#{App.base_url}/threads/#{UniqueId.get}"
      end
    end
  end

  def assign_ids
    if self.local?
      if self.id.blank?
        self.id = UniqueId.get
      end
      if self.public_id.blank?
        self.public_id = "#{self.user.activitystream_url}/#{self.id}"
      end
    end
  end
end
