class APITrendsController < ApplicationController
  self.path = "#{App.api_base_path}/api/v1/trends"

  before do
    content_type :json
  end

  get "/" do
    json([])
  end

  get "/statuses" do
    json([])
  end
end
