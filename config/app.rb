require "sanitize"
require "pledge"
require "gd2-ffij"

# eagerly load so we don't need pledge(rpath)
Dir.glob(Gem.loaded_specs["gd2-ffij"].full_gem_path + "/lib/gd2/*.rb").each do |f|
  require f
end

class App
  cattr_accessor :domain, :site_title
end

App.name = "Notes"
App.domain = "example.com"
App.site_title = "#{App.domain} #{App.name}"
App.exception_recipients = [ "user@example.com" ]

if App.development?
  App.base_url = "http://localhost:4567/notes"
else
  App.base_url = "https://#{App.domain}/notes"
end

App.set :sessions, App.sessions.merge({
  :secure => App.production?,
  :expire_after => 2.weeks,
})
