class APINotificationsController < ApplicationController
  self.path = "#{App.api_base_path}/api/v1/notifications"

  before do
    content_type :json
    find_api_token
    find_api_token_user
  end

  get "/" do
    ns = @api_token.user.notifications.order("created_at DESC").limit(15)

    json(ns.map{|n| n.timeline_object })
  end
end
