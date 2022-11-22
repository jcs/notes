class Note < DBModel
  # include @...@...
  LINKIFY_RE = %r{
      (?: ((?:ed2k|ftp|http|https|irc|mailto|news|gopher|nntp|telnet|webcal|xmpp|callto|feed|svn|urn|aim|rsync|tag|ssh|sftp|rtsp|afs|file):)// | www\.\w |@([a-zA-Z0-9_\-\.]+)@([a-zA-Z0-9_\-\.]+)\.)
      [^\s<\u00A0'",]+
    }ix

  belongs_to :contact
  belongs_to :parent_note,
    :class_name => "Note"
  has_many :attachments,
    :dependent => :destroy
  has_one :user,
    :through => :contact

  validates_presence_of :contact

  scope :timeline, -> { order("created_at DESC") }

  before_create :assign_conversation

  after_create do
    if local? then self.activitystream_publish!("Create") end
  end
  before_destroy do
    if local? then self.activitystream_publish!("Delete") end
  end

  def self.ingest_note!(asvm)
    if !asvm.is_a?(ActivityStreamVerifiedMessage)
      raise "#{asvm.class} not a ActivityStreamVerifiedMessage"
    end

    note = asvm.message["object"]
    if !note || note["id"].blank?
      raise "note has no id"
    end

    dbnote = asvm.contact.notes.where(:foreign_id => note["id"]).first
    if !dbnote
      dbnote = Note.new
      dbnote.contact_id = asvm.contact.id
      dbnote.foreign_id = note["id"]
    end
    dbnote.created_at = DateTime.parse(note["published"])
    if note["updated"] && note["updated"] != note["published"]
      dbnote.note_modified_at = DateTime.parse(note["updated"])
    end
    dbnote.foreign_object = note.to_json
    dbnote.conversation = note["conversation"]
    dbnote.note = note["content"]
    dbnote.save!
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
      "id" => "#{self.user.activitystream_url}/#{self.id}",
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
      q.action = "signed_post"
      q.contact_id = follower.contact.id
      q.user_id = self.contact.user.id
      q.object_json = js
      q.save!
    end
  end

  def html
    linkified_note
  end

  def linkified_note(opts = {})
    if !opts[:target]
      opts[:target] = "_blank"
    end

    html = "<p>" << note.strip.gsub(/\n\n+/, "</p><p>").gsub("\n", "<br>") <<
      "</p>"
    html.gsub!(/<p>(<br>)*<\/p>/, "")

    doc = Nokogiri::HTML(html)
    doc.xpath("//text()").each do |node|
      if node.parent && node.parent.name.downcase == "a"
        next
      end

      text = node.content
      text.gsub!(LINKIFY_RE) do |link|
        title = link.dup

        if m = link.match(/^@([^@]+)@([^@]+)/)
          if m[2] == "twitter.com"
            link = "https://twitter.com/#{m[1]}"
          else
            link = "#{App.base_url}/locate/#{CGI.escape(m[1] + "@" + m[2])}"
          end
        end

        "<a href=\"" << CGI.escapeHTML(link) << "\">" <<
          CGI.escapeHTML(title) << "</a>"
      end

      node.replace text
    end

    Sanitize.fragment(doc.xpath("//body").inner_html,
      Sanitize::Config.merge(Sanitize::Config::RELAXED,
      :add_attributes => {
        "a" => {
          "rel" => "nofollow noreferrer",
          "target" => opts[:target],
        }
      }))
  end

  def local?
    !!self.contact.user
  end

  def thread
    tns = Note.where(:conversation => self.conversation).
      order(:created_at).to_a
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
end
