class OutboxController < ApplicationController
  self.path = "#{App.base_path}/outbox"

  PER_PAGE = 20

  before do
    @scope = @user.notes
    @count = @scope.count
    @pages = (@count.to_f / PER_PAGE.to_f).ceil
  end

  get "/", :provides => ActivityStream::ACTIVITY_TYPES do
    content_type ActivityStream::ACTIVITY_TYPE
    {
      "@context" => ActivityStream::NS,
      "id" => "#{@user.activitystream_url}/outbox",
      "attributedTo" => @user.activitystream_actor,
      "type" => "OrderedCollection",
      "totalItems" => @count,
      "first" => "#{@user.activitystream_url}/outbox/page/#{@pages}",
      "last" => "#{@user.activitystream_url}/outbox/page/1",
    }.to_json
  end

  get "/page/:page", :provides => ActivityStream::ACTIVITY_TYPES do
    page = params[:page].to_i
    if page < 1 || page > @pages
      halt 404, "no such page"
    end

    out = {
      "@context" => ActivityStream::NS,
      "id" => "#{@user.activitystream_url}/outbox/page/#{page}",
      "type" => "OrderedCollectionPage",
      "attributedTo" => @user.activitystream_actor,
      "totalItems" => @count,
      "partOf" => "#{@user.activitystream_url}/outbox",
      "orderedItems" => [],
    }

    if page > 1
      out["prev"] = "#{@user.activitystream_url}/outbox/page/#{page - 1}"
    end
    if page < @pages
      out["next"] = "#{@user.activitystream_url}/outbox/page/#{page + 1}"
    end

    @scope.order("id ASC").limit(PER_PAGE).
    offset((page - 1) * PER_PAGE).each do |note|
      out["orderedItems"].push note.activitystream_object
    end

    content_type ActivityStream::ACTIVITY_TYPE
    out.to_json
  end
end
