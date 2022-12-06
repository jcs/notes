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
      end
    end

    ret.to_json
  end

  post "/" do
    [ :home, :notifications ].each do |what|
      if params[what] && params[what][:last_read_id]
        @api_token.user.store_marker_for(what, params[what][:last_read_id])
      end
    end

    {}.to_json
  end
end
