class InboxController < ApplicationController
  self.path = "#{BASE_PATH}/inbox"

  post "/" do
    asvm = ActivityStream.verified_message_from(request)
    if !asvm
      App.logger.error "HTTP signature verification failed, body: " <<
        request.body.read.inspect
      halt 400, "HTTP signature verification failed"
    end

    App.logger.info "[c#{asvm.contact.id}] verified message from " <<
      "#{asvm.contact.actor}: #{asvm.message.inspect}"

    type = if asvm.message["object"]
      asvm.message["object"]["type"]
    end

    case asvm.message["type"]
    when "Create"
      case type
      when "Note"
        if (note = Note.ingest_note!(asvm))
          App.logger.info "[c#{note.contact.id}] [n#{note.id}] created note"
        end
      else
        App.logger.error "unsupported Create for #{type}"
      end

    when "Delete"
      case type
      when "Tombstone"
        if (note = asvm.contact.notes.
        where(:foreign_id => asvm.message["object"]["id"]).first)
          App.logger.info "[c#{asvm.contact.id}] [n#{note.id}] deleted note"
          note.destroy
        end
      when "User"
        if (f = @user.followers.where(:contact_id => asvm.contact.id).first)
          f.destroy
          App.logger.info "[c#{asvm.contact.id}] unfollowed user"
        end
      else
        App.logger.error "unsupported Delete for #{type}"
      end

    when "Follow"
      case type
      when "Person"
        @user.activitystream_gain_follower!(asvm.contact, asvm.message)
      else
        App.logger.error "unsupported Follow for #{type}"
      end

    when "Undo"
      case type
      when "Follow"
        if (f = @user.followers.where(:contact_id => asvm.contact.id).first)
          f.destroy
          App.logger.info "[c#{asvm.contact.id}] unfollowed user"
        end
      else
        App.logger.error "unsupported Undo for #{type}"
      end

    when "Update"
      case type
      when "Note"
        if (note = Note.ingest_note!(asvm))
          App.logger.info "[c#{note.contact.id}] [n#{note.id}] updated note"
        end
      when "Person"
        Contact.queue_refresh_for_actor!(asvm.contact.actor)
      else
        App.logger.error "unsupported Update for #{type}"
      end

    else
      App.logger.error "unsupported #{asvm.message["type"]} action"
    end

    "got it"
  end
end
