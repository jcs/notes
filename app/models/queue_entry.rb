class QueueEntry < DBModel
  belongs_to :contact
  belongs_to :user
  belongs_to :note

  ACTIONS = {
    :attachment_fetch => proc{|qe|
      Attachment.fetch_for_queue_entry(qe)
    },
    :contact_refresh => proc{|qe|
      Contact.refresh_for_queue_entry(qe)
    },
    :signed_post => proc{|qe|
      ActivityStream.signed_post_with_key(qe.contact.inbox, qe.object_json,
        qe.user.activitystream_key_id, qe.user.private_key)
    },
  }

  MAX_TRIES = 8

  before_create :assign_first_try

  def object
    @_object ||= JSON.parse(self.object_json)
  end

  def process!
    ok = false

    if !ACTIONS[self.action.to_sym]
      raise "unknown action #{self.action.inspect}"
    end

    ret, err = ACTIONS[self.action.to_sym].call(self)
    if ret
      self.destroy
      return
    end

    App.logger.error "[q#{self.id}] failed #{self.action}: #{err}"

    if self.tries >= MAX_TRIES
      App.logger.error "[q#{self.id}] too many retries, giving up"
      self.destroy
      return
    end

    self.tries += 1
    self.next_try_at = Time.now + (2 ** (self.tries + 5))
    self.save!

    App.logger.info "[q#{self.id}] retrying at #{self.next_try_at}"
  end

private
  def assign_first_try
    self.tries = 0
    self.next_try_at = Time.now
  end
end
