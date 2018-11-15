module Sinatra
  module HTMLEscapeHelper
    def h(text)
      Rack::Utils.escape_html(text)
    end
  end

  class Base
    helpers Sinatra::HTMLEscapeHelper
  end
end
