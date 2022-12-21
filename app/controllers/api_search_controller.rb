class APISearchController < ApplicationController
  self.path = "#{App.api_base_path}/api/v2/search"

  before do
    content_type :json
    find_api_token
    find_api_token_user
  end

  get "/" do
    if params[:q].empty?
      return json({})
    end

    if params[:q].include?("@")
      if !Contact.where(:address => params[:q]).first && params[:resolve]
        Contact.refresh_for_actor(params[:q])
      end
    end

    q = "%#{params[:q].gsub(/^@/, "")}%"
    contacts = Contact.where("address LIKE ? OR actor LIKE ?", q, q).limit(5)

    json({
      "accounts" => contacts.map{|c| c.timeline_object },
      "statuses" => [],
      "hashtags" => [],
    })
  end
end
