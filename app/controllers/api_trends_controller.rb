class APITrendsController < ApplicationController
  self.path = "#{App.api_base_path}/api/v1/trends"

  before do
    content_type :json
    find_api_token
  end

  get "/" do
    find_api_token_user

    [].to_json
  end
end
