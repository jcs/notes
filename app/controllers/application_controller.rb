class ApplicationController < App
  set :default_builder, "GroupedFieldFormBuilder"

  use Rack::Csrf, :raise => false

private
  def json(data)
    content_type :json
    data.is_a?(String) ? data : data.to_json
  end
end
