class APIMediaController < ApplicationController
  self.path = "#{App.api_base_path}/api/v1/media"

  before do
    content_type :json
    find_api_token
    find_api_token_user
  end

  post "/" do
    a, err = Attachment.build_from_upload(params[:file])
    if !a
      halt 400, "failed uploading: #{err}"
    end

    a.summary = params[:description]
    a.save!

    json(a.api_object)
  end

  put "/:id" do
    a = Attachment.find_by_id(params[:id])
    if !a
      halt 404
    end

    a.summary = params[:description]
    a.save!

    # TODO: store/update focus

    json(a.api_object)
  end
end
