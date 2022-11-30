# XXX: why does metatext go from /oauth/* to /notes/oauth/*?
class NotesOauthController < ApplicationController
  self.path = "#{App.base_path}/oauth"

  before do
    content_type :json
  end

  # https://docs.joinmastodon.org/methods/oauth/#token
  post "/token" do
    app = ApiApp.where(:client_id => params[:client_id]).first
    if !app
      halt 400, "invalid client_id"
    end

    if app.client_secret != params[:client_secret]
      halt 400, "invalid client_secret"
    end

    if params[:code].blank?
      halt 400, "invalid code"
    end

    token = app.api_tokens.where(:code => params[:code]).first
    if !token
      halt 400, "invalid code"
    end

    if !app.redirect_uri.starts_with?(params[:redirect_uri])
      halt 400, "redirect_uri #{params[:redirect_uri].inspect} is not under " <<
        "#{@app.redirect_uri.inspect}"
    end

    if !token.can_request_scopes?(params[:scope])
      halt 400, "cannot request scope #{params[:scope].inspect}"
    end

    # only allow a code to be used once
    token.code = nil
    token.save!

    json({
      "access_token" => token.access_token,
      "token_type" => "Bearer",
      "scope" => params[:scope],
      "created_at" => token.created_at.to_i,
    })
  end

  post "/revoke" do
    app = ApiApp.where(:client_id => params[:client_id]).first
    if !app
      halt 400, "invalid client_id"
    end

    if app.client_secret != params[:client_secret]
      halt 400, "invalid client_secret"
    end

    token = app.api_tokens.where(:access_token => params[:token]).first
    if !token
      halt 400, "invalid token"
    end

    token.destroy

    json({})
  end
end

