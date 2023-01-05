class WellknownController < ApplicationController
  self.path = "/.well-known"

  get "/host-meta" do
    content_type "application/xml"
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
      "<XRD xmlns=\"http://docs.oasis-open.org/ns/xri/xrd-1.0\">" +
      "<Link rel=\"lrdd\" " +
        "template=\"https://#{App.domain}/.well-known/webfinger?" +
        "resource={uri}\"/>" +
      "</XRD>"
  end

  get "/nodeinfo" do
    json({
      "links" => [
        {
          "rel" => "http://nodeinfo.diaspora.software/ns/schema/2.0",
          "href" => "#{App.base_url}/nodeinfo/2.0",
        },
      ],
    })
  end

  get "/webfinger" do
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
