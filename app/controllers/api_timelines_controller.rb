class APITimelinesController < ApplicationController
  self.path = "#{App.api_base_path}/api/v1/timelines"

  before do
    content_type :json
    find_api_token
  end

  get "/home" do
    find_api_token_user

    tl = @api_token.user.notes_from_followed.limit(20)

    if params[:max_id]
      tl = tl.where("id < ?", params[:max_id])
    end
    if params[:min_id]
      tl = tl.where("id > ?", params[:min_id])
    end

    json(tl.map{|n| n.timeline_object_for(@api_token.user) })
  end

  get "/public" do
    [].to_json
  end
end
