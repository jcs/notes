class QueueEntry < DBModel
  belongs_to :contact
  belongs_to :user

  ACTIONS = [
    :contact_refresh,
    :contact_refresh_for_actor,
    :note_create,
    :signed_post,
  ]

  MAX_TRIES = 10

  before_create :assign_first_try

  def object
    @_object ||= JSON.parse(self.object_json)
  end

  def process!
    ok = false

    if !ACTIONS.include?(self.action.to_sym)
      raise "unknown action #{self.action.inspect}"
    end

    if self.send(self.action)
      self.destroy
      return
    end

    if self.tries >= MAX_TRIES
      App.logger.error "[q#{self.id}] too many retries, giving up"
      self.destroy
      return
    end

    self.tries += 1
    self.next_try_at = Time.now + (2 ** (self.tries + 3))
    self.save!

    App.logger.info "[q#{self.id}] failed, retrying at #{self.next_try_at}"
  end

  # actions

  def contact_refresh_for_actor
    Contact.refresh_for_actor(self.object["actor"], nil, true)
  end

  def contact_refresh
    if !self.contact.refresh!
      return false
    end

    App.logger.info "[q#{self.id}] [c#{self.contact.id}] refreshed " <<
      "contact #{self.contact.address}"
    true
  end

  def note_create
    self.user.activitystream_signed_post_to_contact(self.contact,
      self.object_json)
  end

  def signed_post
    ActivityStream.signed_post_with_key(self.contact.inbox, self.object_json,
      self.user.activitystream_key_id, self.user.private_key)
  end

private
  def assign_first_try
    self.tries = 0
    self.next_try_at = Time.now
  end
end
