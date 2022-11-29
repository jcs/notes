class ApplicationController < App
  set :default_builder, "GroupedFieldFormBuilder"

  use Rack::Csrf, :raise => false, :skip_if => lambda {|req|
    # :skip => [ "POST:/notes/inbox" ] should work but request.path_info is not
    # set properly with our routing
    req.request_method.upcase == "POST" &&
      (req.env["REQUEST_PATH"] == "#{App.base_path}/inbox" ||
      req.env["REQUEST_PATH"].starts_with?("#{App.base_path}/api/v1") ||
      req.env["REQUEST_PATH"] == "#{App.base_path}/oauth/token")
  }

  before do
    if request.env["CONTENT_TYPE"].to_s.match(/\Aapplication\/json(\z|;)/)
      request.env["rack.input"].rewind
      JSON.parse(request.env["rack.input"].read).each do |k,v|
        request.update_param(k,v)
        params[k] = v
      end
    end

    @user = User.includes(:contact).first!
  end

private
  def json(data)
    content_type :json
    data.is_a?(String) ? data : data.to_json
  end

  def find_api_token
    m = request.env["HTTP_AUTHORIZATION"].to_s.match(/\ABearer (.+)\z/)
    if !m || !m[1]
      halt 403, "no token"
    end

    @api_token = ApiToken.where(:access_token => m[1]).includes(:user).first
    if !@api_token
      halt 403, "no token"
    end

    if @api_token.user
      request.log_extras[:api_token_user] = @api_token.user.id
    end
  end

  def find_api_token_user
    if !@api_token
      find_api_token
    end

    if !@api_token.user
      halt 403, "token does not permit user access"
    end
  end
end
