class APIStatusesController < ApplicationController
  self.path = "#{App.base_path}/api/v1/statuses"

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
    n.for_timeline = true

    html, mentions = HTMLSanitizer.linkify_with_mentions(params[:status])
    n.note = html

    n.mentioned_contact_ids = []
    mentions.each do |m|
      c = Contact.where(:address => m[:address]).first
      if !c
        begin
          Timeout.timeout(1.5) do
            c, err = Contact.refresh_for_actor(m[:address], nil, false)
          end
        rescue Timeout::Error
        end
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

      App.logger.info "new note: #{n.activitystream_object.inspect}"

      n.save!
    end

    json(n.timeline_object_for(@api_token.user))
  end

  get "/:id" do
    note = Note.where(:id => params[:id]).first
    if !note
      halt 404, {}
    end
    note.timeline_object_for(@api_token.user).to_json
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
        ancs.push n.timeline_object_for(@api_token.user)
      else
        decs.push n.timeline_object_for(@api_token.user)
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

    note.timeline_object_for(@api_token.user).to_json
  end

  post "/:id/unfavourite" do
    note = Note.where(:id => params[:id]).first
    if !note
      halt 404, {}
    end
    @api_token.user.activitystream_dislike_note!(note)

    note.timeline_object_for(@api_token.user).to_json
  end
end
