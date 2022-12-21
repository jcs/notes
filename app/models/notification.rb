class Notification < DBModel
  belongs_to :user
  belongs_to :note
  belongs_to :contact

  def self.create_for!(obj)
    n = Notification.new
    n.created_at = obj.created_at

    case obj
    when Follower
      n.type = "follow"
      n.user_id = obj.user_id
      n.contact_id = obj.contact_id
    when Forward
      n.type = "reblog"
      n.user_id = obj.note.contact.user.id
      n.contact_id = obj.contact_id
      n.note_id = obj.note_id
    when Like
      n.type = "favourite"
      n.user_id = obj.note.contact.user.id
      n.contact_id = obj.contact_id
      n.note_id = obj.note_id
    else
      return
    end

    n.save!
  rescue ActiveRecord::RecordNotUnique
  end

  def api_object
    ret = {
      "id" => self.id.to_s,
      "type" => self.type,
      "created_at" => self.created_at.utc.iso8601,
    }

    if self.contact
      ret["account"] = self.contact.api_object
    end

    if self.note
      ret["status"] = self.note.api_object_for(self.user)
    end

    ret
  end
end
