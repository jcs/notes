class APIController < ApplicationController
  self.path = "#{App.api_base_path}/api/v1"

  before do
    content_type :json
  end

  # https://docs.joinmastodon.org/methods/instance/#v2
  get "/instance" do
    json({
      "uri" => App.domain,
      "title" => App.site_title,
      "short_description" => App.site_title,
      "description" => "",
      "email" => App.owner,
      "version" => "1.0.0",
      "thumbnail" => User.first.contact.avatar_url,
      "languages" => [ "en" ],
      "registrations" => false,
      "approval_required" => false,
      "invites_enabled" => false,
      "configuration" => {
        "accounts" => {
          "max_featured_tags" => 10
        },
        "statuses" => {
          "max_characters" => 5000,
          "max_media_attachments" => 4,
          "characters_reserved_per_url" => 23
        },
        "media_attachments" => {
          "supported_mime_types" => [
            "image/jpeg",
            "image/png",
            "image/gif",
            "image/heic",
            "image/heif",
            "image/webp",
            "image/avif",
            "video/webm",
            "video/mp4",
            "video/quicktime",
            "video/ogg",
            "audio/wave",
            "audio/wav",
            "audio/x-wav",
            "audio/x-pn-wave",
            "audio/vnd.wave",
            "audio/ogg",
            "audio/vorbis",
            "audio/mpeg",
            "audio/mp3",
            "audio/webm",
            "audio/flac",
            "audio/aac",
            "audio/m4a",
            "audio/x-m4a",
            "audio/mp4",
            "audio/3gpp",
            "video/x-ms-asf"
          ],
          "image_size_limit" => 10485760,
          "image_matrix_limit" => 16777216,
          "video_size_limit" => 41943040,
          "video_frame_rate_limit" => 60,
          "video_matrix_limit" => 2304000
        },
      },
    })
  end

  # https://docs.joinmastodon.org/methods/apps/
  post "/apps" do
    a = ApiApp.new
    a.client_name = params[:client_name]
    a.redirect_uri = params[:redirect_uris]
    a.scopes = params[:scopes]
    a.website = params[:website]
    if a.save
      json({
        "id" => a.id.to_s,
        "name" => a.client_name,
        "website" => a.website,
        "redirect_uri" => a.redirect_uri,
        "client_id" => a.client_id,
        "client_secret" => a.client_secret,
      })
    else
      request.log_extras[:errors] = a.errors.inspect
      halt 422, "invalid input"
    end
  end
end
