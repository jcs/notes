require "sanitize"
require "pledge"
require "gd2-ffij"

# eagerly load so we don't need pledge(rpath)
Dir.glob(Gem.loaded_specs["gd2-ffij"].full_gem_path + "/lib/gd2/*.rb").each do |f|
  require f
end

class App
  cattr_accessor :domain, :site_title, :owner, :attachment_base_url
end

App.name = "Notes"
App.domain = "example.com"
App.base_path = "/notes"
App.site_title = "#{App.domain} #{App.name}"
App.owner = "user@example.com"
App.exception_recipients = [ App.owner ]

if App.development?
  App.base_url = "http://localhost:4567#{App.base_path}"
else
  App.base_url = "https://#{App.domain}#{App.base_path}"
end

App.attachment_base_url = App.base_url

App.set :sessions, App.sessions.merge({
  :secure => App.production?,
  :expire_after => 2.weeks,
})
