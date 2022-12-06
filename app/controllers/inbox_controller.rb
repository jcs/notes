class InboxController < ApplicationController
  self.path = "#{App.base_path}/inbox"

  post "/" do
    asvm, err = ActivityStream.verified_message_from(request)
    if !asvm
      request.log_extras[:error] = err
      halt 400, request.log_extras[:error]
    end

    type = if asvm.message["object"]
      asvm.message["object"]["type"]
    end

    request.log_extras[:contact] = asvm.contact.id
    request.log_extras[:actor] = asvm.contact.actor
    request.log_extras[:message_type] = asvm.message["type"]
    request.log_extras[:object_type] = type

    case asvm.message["type"]
    when "Accept"
      # nothing to do

    when "Announce"
      if (note = @user.contact.notes.where(:public_id =>
      asvm.message["object"]).first)
        note.forward_by!(asvm.contact)
        request.log_extras[:note] = note.id
        request.log_extras[:result] = "forwarded note"
      end

    when "Create"
      case type
      when "Note"
        if (note = Note.ingest_note!(asvm))
          request.log_extras[:note] = note.id
          request.log_extras[:result] = "created note"
        end
      else
        request.log_extras[:error] = "unsupported Create for #{type}"
      end

    when "Delete"
      case type
      when "Tombstone"
        if (note = asvm.contact.notes.
        where(:public_id => asvm.message["object"]["id"]).first)
          note.destroy
          request.log_extras[:note] = note.id
          request.log_extras[:result] = "deleted note"
        end
      when "User"
        if (f = @user.followers.where(:contact_id => asvm.contact.id).first)
          f.destroy
          request.log_extras[:result] = "unfollowed user"
        end
      else
        request.log_extras[:error] = "unsupported Delete for #{type}"
      end

    when "Follow"
      case type
      when "Person", nil
        @user.activitystream_gain_follower!(asvm.contact, asvm.message)
      else
        request.log_extras[:error] = "unsupported Follow for #{type}"
      end

    when "Like"
      if (note = @user.contact.notes.where(:public_id =>
      asvm.message["object"]).first)
        note.like_by!(asvm.contact)
        request.log_extras[:note] = note.id
        request.log_extras[:result] = "liked note"
      end

    when "Undo"
      case type
      when "Announce"
        if (note = @user.contact.notes.where(:public_id =>
        asvm.message["object"]["object"]).first)
          note.unforward_by!(asvm.contact)
          request.log_extras[:note] = note.id
          request.log_extras[:result] = "unforwarded"
        end

      when "Like"
        if (note = @user.contact.notes.where(:public_id =>
        asvm.message["object"]["object"]).first)
          note.unlike_by!(asvm.contact)
          request.log_extras[:note] = note.id
          request.log_extras[:result] = "unliked"
        end

      when "Follow"
        if (f = @user.followers.where(:contact_id => asvm.contact.id).first)
          f.destroy
          request.log_extras[:result] = "unfollowed"
        end
      else
        request.log_extras[:error] = "unsupported Undo for #{type}"
      end

    when "Update"
      case type
      when "Note"
        if (note = Note.ingest_note!(asvm))
          request.log_extras[:note] = note.id
          request.log_extras[:result] = "updated note"
        end
      when "Person"
        c = Contact.where(:actor => asvm.contact.actor).first
        if c && c.local?
          request.log_extras[:error] = "ignoring Update for local contact"
        else
          Contact.queue_refresh_for_actor!(asvm.contact.actor)
        end
      when "Question"
        # ignore
      else
        request.log_extras[:error] = "unsupported Update for #{type}"
      end

    else
      request.log_extras[:error] = "unsupported #{asvm.message["type"]} action"
    end

    "got it"
  end
end
