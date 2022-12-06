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

  validates_presence_of :contact

  scope :timeline, -> { order("created_at DESC") }

  before_create :assign_conversation, :assign_ids

  after_create do
    if local? then self.activitystream_publish!("Create") end
  end
  before_destroy do
    if local? then self.activitystream_publish!("Delete") end
  end

  attr_accessor :like_count, :reply_count, :forward_count

  def self.ingest_note!(asvm)
    if !asvm.is_a?(ActivityStreamVerifiedMessage)
      raise "#{asvm.class} not a ActivityStreamVerifiedMessage"
    end

    note = asvm.message["object"]
    if !note || note["id"].blank?
      raise "note has no id"
    end

    dbnote = asvm.contact.notes.where(:public_id => note["id"]).first
    if !dbnote
      dbnote = Note.new
      dbnote.contact_id = asvm.contact.id
      dbnote.public_id = note["id"]
    end
    dbnote.created_at = DateTime.parse(note["published"])
    if note["updated"] && note["updated"] != note["published"]
      dbnote.note_modified_at = DateTime.parse(note["updated"])
    end
    dbnote.foreign_object_json = note.to_json
    dbnote.conversation = note["conversation"]
    dbnote.note = note["content"]

    dbnote.is_public = (note["to"].is_a?(Array) ? note["to"].to_s :
      [ note["to"] ]).include?(ActivityStream::PUBLIC_URI)
    if dbnote.is_public
      if note["inReplyTo"].present? &&
      !note["inReplyTo"].starts_with?(App.base_url)
        # TODO: check for mentions of us
        dbnote.is_public = false
      end
    end

    if note["inReplyTo"].present? &&
    (parent = Note.where(:public_id => note["inReplyTo"]).first)
      dbnote.parent_note_id = parent.id
    end

    dbnote.save!

    # match our attachment list with the note's, deleting or creating as
    # necessary
    have = dbnote.attachments.to_a
    want = dbnote.foreign_object["attachment"] || []
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
      qe = QueueEntry.new
      qe.action = :attachment_fetch
      qe.note_id = dbnote.id
      qe.object_json = obj.to_json
      qe.save!
    end

    dbnote
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

    {
      "@context" => ActivityStream::NS,
      "id" => self.public_id,
      "type" => "Note",
      "published" => self.created_at.utc.iso8601,
      "updated" => self.note_modified_at ?
        self.note_modified_at.utc.iso8601 : nil,
      "to" => [ ActivityStream::PUBLIC_URI ],
      "cc" => [ "#{self.user.activitystream_url}/followers" ],
      "context" => self.conversation,
      "attributedTo" => self.user.activitystream_actor,
      "content" => self.linkified_note,
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
      "attachment" => self.attachments.order("id").map{|a|
        a.activitystream_object
      },
    }
  end

  def activitystream_publish!(verb)
    js = self.activitystream_activity_object(verb).to_json

    self.user.followers.includes(:contact).each do |follower|
      q = QueueEntry.new
      q.action = :signed_post
      q.user_id = self.contact.user.id
      q.contact_id = follower.contact.id
      q.note_id = self.id
      q.object_json = js
      q.save!
    end
  end

  def authoritative_url
    self.local? ? self.url : self.public_id
  end

  def foreign_object
    @foreign_object ||= JSON.parse(self.foreign_object_json || "{}")
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

  def html
    linkified_note
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

  def linkified_note(opts = {})
    HTMLSanitizer.linkify(note, opts)
  end

  def local?
    self.contact.local?
  end

  def reply_count
    @reply_count ||= Note.where(:parent_note_id => self.id).count
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
      "created_at" => self.created_at.utc.iso8601,
      "edited_at" => self.note_modified_at.try(:utc).try(:iso8601),
      "in_reply_to_id" => self.parent_note_id.try(:to_s),
      "in_reply_to_account_id" => self.parent_note_id.present? ?
        self.parent_note.contact_id.to_s : nil,
      "sensitive" => !!foreign_object["sensitive"],
      "spoiler_text" => "",
      "visibility" => "public",
      "language" => "en",
      "url" => self.public_id,
      "uri" => self.public_id,
      "replies_count" => self.reply_count,
      "reblogs_count" => self.forward_count,
      "favourites_count" => self.like_count,
      "favourited" => user.likes.where(:note_id => self.id).any?,
      #"reblogged" => false,
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
    if (l = self.forwards.where(:contact_id => contact.id).first)
      l.destroy
    end
  end

  def unlike_by!(contact)
    if (l = self.likes.where(:contact_id => contact.id).first)
      l.destroy
    end
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
