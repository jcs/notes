class WebfingerController < ApplicationController
  self.path = "/.well-known/webfinger"

  get "/" do
    acct = params[:resource].to_s.scan(/\Aacct:(.+)\z/).flatten[0]
    unless acct then halt 404, "invalid acct" end

    user = User.find_by_address(acct)
    unless user then halt 404, "no such user" end

    content_type "application/jrd+json"
    {
      "subject" => "acct:#{user.address}",
      "links" => [
        {
          "href" => App.base_url,
          "rel" => "self",
          "type" => ActivityStream::ACTIVITY_TYPE,
        },
        {
          "href" => App.base_url,
          "rel" => WebFinger::PROFILE_PAGE,
          "type" => "text/html",
        },
      ],
    }.to_json
  end
end
