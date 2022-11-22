class ApplicationController < App
  set :default_builder, "GroupedFieldFormBuilder"

  BASE_PATH = "/notes"

  use Rack::Csrf, :raise => false, :skip_if => lambda {|req|
    # :skip => [ "POST:/notes/inbox" ] should work but request.path_info is not
    # set properly with our routing
    req.request_method.upcase == "POST" &&
      req.env["REQUEST_PATH"] == "/notes/inbox"
  }

  before do
    @user = User.includes(:contact).first!
  end

private
  def json(data)
    content_type :json
    data.is_a?(String) ? data : data.to_json
  end
end
