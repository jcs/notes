class APIStatusesController < ApplicationController
  self.path = "#{App.base_path}/api/v1/statuses"

  before do
    content_type :json
    find_api_token
    find_api_token_user
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
