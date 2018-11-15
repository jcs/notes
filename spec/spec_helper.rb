require "minitest/autorun"
require "rack/test"

ENV["APP_ENV"] = "test"

require File.realpath(File.dirname(__FILE__) + "/../lib/app.rb")

if File.exist?(_f = ActiveRecord::Base.connection_config[:database])
  File.unlink(_f)
end

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.connection.migration_context.migrate

include Rack::Test::Methods

def app
  Rubywarden::App
end
