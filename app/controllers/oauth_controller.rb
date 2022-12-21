class OauthController < ApplicationController
  # hardcoded
  self.path = "/oauth"

  # https://docs.joinmastodon.org/methods/oauth/#authorize
  get "/authorize" do
    if params[:response_type] != "code"
      halt 400, "invalid response_type"
    end

    @app = ApiApp.where(:client_id => params[:client_id]).first
    if !@app
      halt 400, "invalid client_id"
    end

    if !@app.can_request_scopes?(params[:scope])
      halt 400, "cannot request scope #{params[:scope].inspect}"
    end

    if !@app.redirect_uri.starts_with?(params[:redirect_uri])
      halt 400, "redirect_uri #{params[:redirect_uri].inspect} is not under " <<
        "#{@app.redirect_uri.inspect}"
    end

    @api_token = ApiToken.new
    @api_token.scope = params[:scope]
    @api_token.api_app = @app
    @api_token.response_type = params[:response_type]
    @api_token.redirect_uri = params[:redirect_uri]
    @api_token.client_id = params[:client_id]

    erb :authorize
  end

  post "/grant_authorization" do
    user = User.find_by_username(params[:api_token][:username])
    if !user
      halt 400, "no username"
    end

    if !user.authenticate(params[:api_token][:password])
      halt 400, "invalid password"
    end

    app = ApiApp.where(:client_id => params[:api_token][:client_id]).first
    if !app
      halt 400, "invalid client_id"
    end

    api_token = ApiToken.new
    api_token.user = user
    api_token.scope = params[:api_token][:scope]
    api_token.api_app = app

    if api_token.save
      if app.redirect_uri == ApiApp::REDIRECT_OOB
        content_type "text/html"
        "<html><body><big><big>#{api_token.code}</big></big></body></html>"
      else
        redirect "#{params[:api_token][:redirect_uri]}?code=#{api_token.code}"
      end
    else
      halt 400, { :error => "invalid" }.to_json
    end
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
end
