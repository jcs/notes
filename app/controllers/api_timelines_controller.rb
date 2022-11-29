class APITimelinesController < ApplicationController
  self.path = "#{App.base_path}/api/v1/timelines"

  before do
    content_type :json
    find_api_token
  end

  get "/home" do
    find_api_token_user

    response["link"] = [
      "<#{App.base_url}/api/v1/timelines/home?max_id=1>; rel=\"next\"",
      "<#{App.base_url}/api/v1/timelines/home?min_id=1>; rel=\"prev\"",
    ].join(", ")

    @api_token.user.timeline.limit(20).map{|n| n.timeline_object }.to_json
  end

  get "/public" do
    [].to_json
  end
end
