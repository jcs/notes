class APIMarkersController < ApplicationController
  self.path = "#{App.base_path}/api/v1/markers"

  before do
    content_type :json
    find_api_token
    find_api_token_user
  end

  get "/" do
    if !params[:timeline] || !params[:timeline].any?
      return {}.to_json
    end

    ret = {}

    params[:timeline].each do |w|
      if (m = @api_token.user.marker_for(w))
        ret[w] = m
      else
        ret[w] = {
          "last_read_id" => "0",
          "version" => 1,
          "updated_at" => Time.at(0).utc.iso8601,
        }
      end
    end

    json(ret)
  end

  post "/" do
    [ :home, :notifications ].each do |what|
      if params[what] && params[what][:last_read_id]
        @api_token.user.store_marker_for(what, params[what][:last_read_id])
      end
    end

    json({})
  end
end
