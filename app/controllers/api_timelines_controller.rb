class APITimelinesController < ApplicationController
  self.path = "#{App.base_path}/api/v1/timelines"

  before do
    content_type :json
    find_api_token
  end

  get "/home" do
    find_api_token_user

    tl = @api_token.user.timeline.order("created_at DESC").limit(20)

    if params[:max_id]
      tl = tl.where("id < ?", params[:max_id])
    end

    tl.map{|n| n.timeline_object }.to_json
  end

  get "/public" do
    [].to_json
  end
end
