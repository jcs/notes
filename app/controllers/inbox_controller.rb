class InboxController < ApplicationController
  self.path = "#{App.base_path}/inbox"

  post "/" do
    asvm, err = ActivityStream.verified_message_from(request)
    if !asvm
      request.log_extras[:error] = err
      halt 400, request.log_extras[:error]
    end

    object_type = if asvm.message["object"].is_a?(Hash)
      asvm.message["object"]["type"]
    else
      asvm.message["object"]
    end
    type = asvm.message["type"]

    request.log_extras[:contact] = asvm.contact.id
    request.log_extras[:actor] = asvm.contact.actor
    request.log_extras[:message_type] = asvm.message["type"]
    request.log_extras[:object_type] = object_type
    request.log_extras[:foreign] = asvm.foreign

    # TODO: remove this once we can verify RsaSignature2017
    if asvm.foreign && !(type == "Create" && object_type == "Note")
      request.log_extras[:error] = "ignoring foreign #{type} message " <<
        "for #{object_type} forwarded by #{asvm.message["actor"]}"
      return [ 201, "got it" ]
    end

    case type
    when "Accept"
      # nothing to do

    when "Announce"
      note = Note.where(:public_id => asvm.message["object"]).first
      if !note
        note, err = Note.ingest_from_url!(asvm.message["object"])
        if note == nil
          request.log_extras[:error] = "failed ingesting note " <<
            "#{asvm.message["object"]}: #{err}"
          break
        end
      end
      note.forward_by!(asvm.contact)
      request.log_extras[:note] = note.id
      request.log_extras[:result] = "forwarded note"

    when "Create"
      case object_type
      when "Note"
        note, err = Note.ingest!(asvm)
        if note == nil
          request.log_extras[:error] = "failed ingesting note: #{err}"
          break
        end
        request.log_extras[:note] = note.id
        request.log_extras[:result] =
          "created #{note.is_public ? "public" : "private"} " <<
          (note.for_timeline? ? "timeline" : "reply") << " note"
      else
        request.log_extras[:error] = "unsupported Create for #{object_type}"
      end

    when "Delete"
      case object_type
      when "Tombstone", "Note"
        if (note = asvm.contact.notes.
        where(:public_id => asvm.message["object"]["id"]).first)
          note.destroy!
          request.log_extras[:note] = note.id
          request.log_extras[:result] = "deleted note"
        end
      when "User"
        if (f = @user.followers.where(:contact_id => asvm.contact.id).first)
          f.destroy!
          request.log_extras[:result] = "unfollowed user"
        end
      when asvm.contact.actor
        if asvm.contact.local?
          raise
        end
        asvm.contact.destroy!
        request.log_extras[:result] = "deleted contact #{asvm.contact.actor}"
      else
        request.log_extras[:error] = "unsupported Delete for #{object_type}"
      end

    when "Follow"
      case object_type
      when @user.contact.actor
        @user.activitystream_gain_follower!(asvm.contact, asvm.message)

      else
        request.log_extras[:error] = "unsupported Follow for #{object_type}"
      end

    when "Like"
      if (note = @user.contact.notes.where(:public_id =>
      asvm.message["object"]).first)
        note.like_by!(asvm.contact)
        request.log_extras[:note] = note.id
        request.log_extras[:result] = "liked note"
      end

    when "Move"
      case object_type
      when asvm.contact.actor
        asvm.contact.move_to!(asvm.message["target"])
        request.log_extras[:result] = "moved to #{asvm.message["target"]}"
      else
        request.log_extras[:error] = "unsupported Move for non-actor " <<
          "#{asvm.message.inspect}"
      end

    when "Undo"
      case object_type
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
          f.destroy!
          request.log_extras[:result] = "unfollowed"
        end
      else
        request.log_extras[:error] = "unsupported Undo for #{object_type}"
      end

    when "Update"
      case object_type
      when "Note"
        note, err = Note.ingest!(asvm)
        if note == nil
          request.log_extras[:error] = "failed ingesting note: #{err}"
        else
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
        request.log_extras[:error] = "unsupported Update for #{object_type}"
      end

    else
      request.log_extras[:error] = "unsupported #{type} action for " <<
        "#{object_type}"
    end

    [ 201, "got it" ]
  end
end
