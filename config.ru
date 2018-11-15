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

if ENV["APP_ENV"] == "production"
  # prevent printing stack traces and other nonsense
  ENV["RACK_ENV"] = "deployment"
end

require File.realpath(__dir__) + "/lib/exceptions.rb"
use Rack::ExceptionMailer

require File.realpath(__dir__) + "/lib/app.rb"

App.all_routes.reject{|_k,_v| _k == :root }.each do |_k,_v|
  map(_k) { run _v }
end

if !(root_route = App.all_routes.select{|_k,_v| _k == :root }.values.first)
  raise "no root route (set \"self.path = :root\" in root controller)"
end

run root_route
