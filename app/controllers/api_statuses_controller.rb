class APIStatusesController < ApplicationController
  self.path = "#{App.api_base_path}/api/v1/statuses"

  before do
    content_type :json
    find_api_token
    find_api_token_user
  end

  post "/" do
    n = Note.new
    n.contact_id = @api_token.user.contact.id
    if params[:in_reply_to_id].present?
      n.parent_note_id = params[:in_reply_to_id]
    end
    n.is_public = (params[:visibility] == "public")

    html, mentions = HTMLSanitizer.linkify_with_mentions(params[:status])
    n.note = html

    n.for_timeline = !n.directed_at_someone?

    n.mentioned_contact_ids = []
    mentions.each do |m|
      c = Contact.where(:address => m[:address]).first
      if !c
        c, _ = Contact.refresh_for_actor_with_timeout(m[:address])
      end

      if c
        n.mentioned_contact_ids.push c.id
      else
        App.logger.error "couldn't find contact for #{m.inspect} " <<
          "when building new note"
      end
    end

    Note.transaction do
      (params[:media_ids] || []).each do |i|
        if (a = Attachment.where(:id => i).first)
          n.attachments.push a
        else
          App.logger.error "can't find attachment #{i} building new note"
        end
      end

      n.save!
      request.log_extras[:note] = n.id
    end

    json(n.api_object_for(@api_token.user))
  end

  get "/:id" do
    note = Note.where(:id => params[:id]).first
    if !note
      halt 404, {}
    end
    json(note.api_object_for(@api_token.user))
  end

  get "/:id/context" do
    note = Note.where(:id => params[:id]).first
    if !note
      halt 404, {}
    end

    ancs = []
    decs = []
    Note.where(:conversation => note.conversation).order("created_at ASC").
    each do |n|
      if n.id == note.id
        next
      end

      if n.id < note.id
        ancs.push n.api_object_for(@api_token.user)
      else
        decs.push n.api_object_for(@api_token.user)
      end
    end

    {
      "ancestors" => ancs,
      "descendants" => decs,
    }.to_json
  end

  post "/:id/favourite" do
    note = Note.where(:id => params[:id]).first
    if !note
      halt 404, {}
    end
    @api_token.user.activitystream_like_note!(note)

    json(note.api_object_for(@api_token.user))
  end

  post "/:id/unfavourite" do
    note = Note.where(:id => params[:id]).first
    if !note
      halt 404, {}
    end
    @api_token.user.activitystream_dislike_note!(note)

    json(note.api_object_for(@api_token.user))
  end
end
