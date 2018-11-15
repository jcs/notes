#
# Copyright (c) 2017-2018 joshua stein <jcs@jcs.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

Encoding.default_internal = Encoding.default_external = Encoding::UTF_8

APP_ROOT = File.realpath(File.dirname(__FILE__) + "/../")

require "active_record"
require "active_support/time"

require "sinatra/base"
require "sinatra/namespace"
require "sinatra/activerecord"
require "cgi"
require "rack/csrf"

# configure mail early in case of exceptions
require "pony"
require "#{APP_ROOT}/config/mail.rb"

class App < Sinatra::Base
  register Sinatra::Namespace
  register Sinatra::ActiveRecordExtension

  # defaults, to be overridden with App.X = "..." in config/app.rb

  # app name used in various places (emails, etc.)
  cattr_accessor :name
  @@name = "App"

  # to be replaced by an absolute url with scheme/domain
  cattr_accessor :base_url
  @@base_url = "/"

  # email addresses to be notified of exceptions
  cattr_accessor :exception_recipients
  @@exception_recipients = []

  # parameters to be filtered from exception notifications and verbose logging
  cattr_accessor :filtered_parameters
  # regexes or strings
  @@filtered_parameters = [ /password/ ]


  # where we're at
  set :root, File.realpath(__dir__ + "/../")

  # config for active record
  set :database_file, "#{App.root}/db/config.yml"

  # gathered later from all controllers
  @@all_routes = {}
  cattr_accessor :all_routes

  # app/views/(controller)/
  set :views, Proc.new { App.root + "/app/views/#{cur_controller}/" }

  # app/views/layouts/(controller).erb or app/views/layouts/application.erb
  set :erb, :layout => Proc.new {
    @@layouts ||= {}
    cc = cur_controller

    if File.exists?(f = App.root + "/app/views/layouts/#{cc}.erb")
      @@layouts[cc] ||= File.read(f)
    else
      @@layouts["application"] ||= File.read(App.root +
        "/app/views/layouts/application.erb")
    end
  }

  # store timestamps in the db in UTC, but convert to Time.zone time when
  # instantiating objects
  Time.zone = "Central Time (US & Canada)"
  ActiveRecord::Base.time_zone_aware_attributes = true

  # non-colored logging
  enable :logging
  ActiveSupport::LogSubscriber.colorize_logging = false
  @@logger = ::Logger.new(STDOUT)
  use Rack::CommonLogger, @@logger

  # encrypted sessions, requiring a per-app secret to be configured
  enable :sessions
  set :sessions, {
    :key => "_session",
    :httponly => true,
    :same_site => :lax,
  }
  begin
    set :session_secret, File.read("#{App.root}/config/session_secret")
  rescue => e
    STDERR.puts e.message
    STDERR.puts "no session secret file",
      "ruby -e 'require \"securerandom\"; " +
      "print SecureRandom.hex(64)' > config/session_secret"
    exit 1
  end

  # allow erb views to be named view.html.erb
  Tilt.prefer Tilt::ErubisTemplate
  Tilt.register Tilt::ErubisTemplate, "html.erb"

  class << self
    alias_method :env, :environment
    attr_accessor :path

    def cur_controller
      raise
    rescue => e
      e.backtrace.each do |z|
        if m = z.match(/app\/controllers\/(.+?)_controller\.rb:/)
          return m[1]
        end
      end

      nil
    end

    def logger
      @@logger
    end

    def production?
      env.to_s == "production"
    end
    def development?
      env.to_s == "development"
    end
    def test?
      env.to_s == "test"
    end
  end

  def flash
    session[:flash] ||= {}
  end

  def logger
    @@logger
  end

  # per-environment configuration
  if File.exists?(_c = "#{App.root}/config/#{App.environment}.rb")
    require _c
  end
end

# bring in model base
require "#{App.root}/lib/db.rb"
require "#{App.root}/lib/db_model.rb"

# and sinatra_more helpers
require "#{App.root}/lib/sinatra_more/markup_plugin.rb"
require "#{App.root}/lib/sinatra_more/render_plugin.rb"

class App
  include SinatraMore::AssetTagHelpers
  include SinatraMore::FormHelpers
  include SinatraMore::FormatHelpers
  include SinatraMore::OutputHelpers
  include SinatraMore::RenderHelpers
  include SinatraMore::TagHelpers
end

# bring in user's models and helpers
Dir.glob("#{App.root}/app/models/*.rb").each{|f| require f }

require "#{App.root}/lib/helpers.rb"
Dir.glob("#{App.root}/app/helpers/*.rb").each do |f|
  require f
end

# and controllers, binding each's helper
(
  [ "#{App.root}/app/controllers/application_controller.rb" ] +
  Dir.glob("#{App.root}/app/controllers/*.rb")
).uniq.each do |f|
  mc = Module.constants
  require f
  newmc = (Module.constants - mc)

  if newmc.count != 1
    raise "#{f} introduced #{newmc.count} new classes instead of 1"
  end
  cont = newmc[0]

  if Kernel.const_defined?(c = cont.to_s.gsub(/Controller$/, "Helper"))
    Kernel.const_get(cont).send(:helpers, Kernel.const_get(c))
  end
end

# and extras
Dir.glob("#{App.root}/app/extras/*.rb").each{|f| require f }

# bring up active record connection
Db.connect(:environment => App.env.to_s)

# dynamically build routes for config.ru
ApplicationController.subclasses.each do |subklass|
  path = subklass.path
  if !path
    # WidgetsController -> "widgets"
    path = "/" << ActiveSupport::Inflector.underscore(
      subklass.to_s.gsub(/Controller$/, ""))
  end

  if !path.is_a?(Array)
    path = [ path ]
  end

  path.each do |p|
    if App.all_routes[p]
      raise "duplicate route for #{p.inspect}: " <<
        "#{App.all_routes[p].inspect} and #{subklass.inspect}"
    end

    App.all_routes[p] = subklass
  end
end

# per-app initialization, not specific to environment
if File.exists?(_c = "#{App.root}/config/app.rb")
  require _c
end
