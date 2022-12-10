class QueueEntry < DBModel
  belongs_to :contact
  belongs_to :user
  belongs_to :note

  ACTIONS = {
    :attachment_fetch => lambda{|qe|
      Attachment.fetch_for_queue_entry(qe)
    },
    :contact_refresh => lambda{|qe|
      contact, err = Contact.refresh_for_queue_entry(qe)
      if contact
        App.logger.info "[q#{qe.id}] [c#{contact.id}] refreshed for " <<
          "#{contact.actor}"
      else
        App.logger.error "[q#{qe.id}] error refreshing: #{err}"
      end
      return contact, err
    },
    :contact_update_avatar => lambda{|qe|
      ret, err = qe.contact.update_avatar!
      if ret
        App.logger.info "[q#{qe.id}] [c#{qe.contact_id}] updated avatar for " <<
          "#{qe.contact.actor}"
      else
        App.logger.error "[q#{qe.id}] [c#{qe.contact_id}] failed updating " <<
          "avatar for #{qe.contact.actor}: #{err}"
      end
      return true, nil
    },
    :signed_post => lambda{|qe|
      begin
        App.logger.info "[q#{qe.id}] [c#{qe.contact.id}] doing signed POST " <<
          "to #{qe.contact.inbox}"
        ret = ActivityStream.fetch(uri: qe.contact.inbox, method: :post,
          body: qe.object.to_json)
        if ret.ok?
          return true, nil
        else
          raise "returned status #{ret.status}"
        end
      rescue StandardError, Timeout::Error => e
        return false, "failed POSTing to #{qe.contact.inbox}: #{e.message}"
      end
    },
  }

  MAX_TRIES = 8

  before_create :assign_first_try

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
    fail!
  end

  def fail!
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
