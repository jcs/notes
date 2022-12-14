class APIAccountsController < ApplicationController
  self.path = "#{App.api_base_path}/api/v1/accounts"

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
    @api_token.user.contact.api_object.to_json
  end

  get "/:id" do
    contact = Contact.where(:id => params[:id]).first
    if !contact
      halt 404, {}
    end
    json(contact.api_object)
  end

  post "/:id/follow" do
    contact = Contact.where(:id => params[:id]).first
    if !contact
      halt 404, {}
    end

    f = @api_token.user.followings.where(:contact_id => contact.id).first
    if !f
      ret, err = @api_token.user.activitystream_follow!(contact.actor)
      if err || ret == nil
        raise 400
      end
    end

    json(contact.relationship_object_with(@api_token.user))
  end

  get "/:id/followers" do
    if params[:id] != @api_token.user.contact.id.to_s
      halt 404
    end

    json(@api_token.user.followers.
      includes(:contact).map{|f| f.contact.api_object })
  end

  get "/:id/following" do
    if params[:id] != @api_token.user.contact.id.to_s
      halt 404
    end

    json(@api_token.user.followings.
      includes(:contact).map{|f| f.contact.api_object })
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

    if !contact.local?
      contact.ingest_recent_notes!
    end

    limit = 20
    if params[:limit].present? && params[:limit].to_i <= 100
      limit = params[:limit].to_i
    end

    scope = Note.where(:contact_id => contact.id).includes(:contact).
      order("created_at DESC").limit(limit)

    if params[:exclude_replies].to_s == "true"
      scope = scope.where(:for_timeline => true)
    end

    if params[:only_media].to_s == "true"
      scope = scope.where("id IN (SELECT note_id FROM attachments)")
    end

    scope.map{|n| n.api_object_for(@api_token.user) }.to_json
  end

  post "/:id/unfollow" do
    f = @api_token.user.followings.where(:contact_id => params[:id]).first
    if !f
      halt 404
    end

    ret, err = f.unfollow!
    if err
      halt 400
    end

    json(f.contact.relationship_object_with(@api_token.user))
  end
end
