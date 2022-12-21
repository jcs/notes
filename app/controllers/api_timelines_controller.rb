class APITimelinesController < ApplicationController
  self.path = "#{App.api_base_path}/api/v1/timelines"

  before do
    content_type :json
    find_api_token
  end

  get "/home" do
    find_api_token_user

    limit = 20
    if params[:limit].present? && params[:limit].to_i <= 100
      limit = params[:limit].to_i
    end

    tl = @api_token.user.notes_from_followed.limit(limit)

    if params[:max_id]
      tl = tl.where("id < ?", params[:max_id])
    end
    if params[:min_id]
      tl = tl.where("id > ?", params[:min_id])
    end

    json(tl.map{|n| n.api_object_for(@api_token.user) })
  end

  get "/public" do
    json([])
  end
end
