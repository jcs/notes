class APIAccountsController < ApplicationController
  self.path = "#{App.base_path}/api/v1/accounts"

  before do
    content_type :json
    find_api_token
    find_api_token_user
  end

  get "/relationships" do
    params[:id].map{|i|
      if contact = Contact.where(:id => i).first
        contact.relationship_object_with(@api_token.user)
      else
        {}
      end
    }.to_json
  end

  get "/verify_credentials" do
    @api_token.user.contact.timeline_object.to_json
  end

  get "/:id" do
    contact = Contact.where(:id => params[:id]).first
    if !contact
      halt 404, {}
    end
    contact.timeline_object.to_json
  end

  get "/:id/following" do

  end

  get "/:id/statuses" do
    contact = Contact.where(:id => params[:id]).first
    if !contact
      halt 404, {}
    end

    if params[:pinned].to_s == "true"
      # XXX: we don't store a contact's "featured" endpoint list
      return [].to_json
    end

    contact.ingest_recent_notes!

    scope = Note.where(:contact_id => contact.id).includes(:contact).
      order("created_at DESC").limit(20)

    if params[:exclude_replies].to_s == "true"
      scope = scope.where(:for_timeline => true)
    end

    scope.map{|n| n.timeline_object_for(@api_token.user) }.to_json
  end
end
