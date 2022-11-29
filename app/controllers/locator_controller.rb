class LocatorController < ApplicationController
  self.path = "#{App.base_path}/locate"

  get "/:acct" do
    acct = params[:acct].to_s.scan(/\A(.+@.+\..+)\z/).flatten[0]
    unless acct then halt 404, "invalid acct" end

    js = WebFinger.finger_account(acct)
    unless js["links"] then halt 404, "no links in webfinger response" end

    link = js["links"].select{|l| l["rel"] == WebFinger::PROFILE_PAGE }.first
    if link
      redirect link["href"]
    end

    link = js["links"].select{|l| l["rel"] == "self" }.first
    if link
      redirect link["href"]
    end

    halt 400, "no URL to redirect to"

  rescue => e
    request.log_extras[:error] = "error locating #{params[:acct]}: #{e.message}"
    halt 404, "error fingering account"
  end
end

