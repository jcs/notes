# this must be included in unicorn.conf.rb after forking, or unicorn won't be
# able to gracefully restart
#
# after_fork do |server, worker|
#   if defined?(ActiveRecord::Base)
#     ActiveRecord::Base.establish_connection
#   end
#
#   require "#{app_dir}/config/pledge_unveil.rb"
# end

if RUBY_PLATFORM.match(/openbsd/i)
  require "unveil"

  Pledge.unveil({
    "#{App.root}/app" => "r",
    "#{App.root}/config" => "r",
    "#{App.root}/db" => "r",
    "#{App.root}/db/production" => "rwc",
    "#{App.root}/lib" => "r",
    "#{App.root}/log" => "rwc",
    "#{App.root}/public" => "r",
    "#{App.root}/tmp" => "rwc",
    "#{App.root}/vendor" => "r",
    "/var/www/notes/socket" => "rwc",
    "/usr/local/lib/ruby" => "r",
    "/tmp" => "rwc",
  })

  # exclude exec
  pledges = [
    "cpath",
    "dns",
    "fattr",
    "flock",
    "inet",
    "proc",
    "prot_exec",
    "rpath",
    "stdio",
    "unix",
    "wpath",
  ]

  Pledge.pledge(pledges.join(" "))

  App.logger.info "pledged and unveiled"
else
  App.logger.warn "not pledged or unveiled on this platform"
end
