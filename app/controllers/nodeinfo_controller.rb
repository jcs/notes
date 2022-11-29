class NodeinfoController < ApplicationController
  self.path = "#{App.base_path}/nodeinfo"

  get "/2.0" do
    json({
      "version" => "2.0",
      "software" => {
        "name" => "notes",
        "version" => "1.0",
      },
      "protocols" => [ "activitypub" ],
      "services" => {
        "outbound" => [],
        "inbound" => [],
      },
      "usage" => {
        "users" => {
          "total" => User.count,
          "activeMonth" => User.count,
          "activeHalfyear" => User.count,
        },
        "localPosts" => User.first.notes.count,
      },
      "openRegistrations" => false,
      "metadata" => {},
    })
  end
end
