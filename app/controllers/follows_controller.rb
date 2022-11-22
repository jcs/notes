class FollowsController < ApplicationController
  self.path = [
    "#{BASE_PATH}/followers",
    "#{BASE_PATH}/following",
  ]

  PER_PAGE = 20

  before do
    if request.path.match(/\A#{Regexp.escape(BASE_PATH)}\/followers/)
      @collection = :followers
      @ar_collection = :followers
      @title = "Followers"
    elsif request.path.match(/\A#{Regexp.escape(BASE_PATH)}\/following/)
      @collection = :following
      @ar_collection = :followings
      @title = "Following"
    else
      halt 404, "what verb is this?"
    end

    @count = @user.send(@ar_collection).count
    @pages = (@count.to_f / PER_PAGE.to_f).ceil
    @base_url = "#{@user.activitystream_url}/#{@collection.to_s}"
  end

  get "/" do
    if ActivityStream.is_for_request?(request)
      content_type ActivityStream::ACTIVITY_TYPE
      {
        "@context" => ActivityStream::NS,
        "id" => @base_url,
        "type" => "OrderedCollection",
        "attributedTo" => @user.activitystream_actor,
        "totalItems" => @count,
        "first" => "#{@base_url}/page/1",
      }.to_json
    else
      @page = 1
      find_items
      erb :index
    end
  end

  get "/page/:page" do
    @page = params[:page].to_i
    if @page < 1 || @page > @pages
      halt 404, "no such page"
    end

    find_items

    if ActivityStream.is_for_request?(request)
      out = {
        "@context" => ActivityStream::NS,
        "id" => "#{@base_url}/page/#{@page}",
        "type" => "OrderedCollectionPage",
        "attributedTo" => @user.activitystream_actor,
        "totalItems" => @count,
        "partOf" => @base_url,
        "orderedItems" => [],
      }

      if @page > 1
        out["prev"] = "#{@base_url}/page/#{@page - 1}"
      end
      if @page < @pages
        out["next"] = "#{@base_url}/page/#{@page + 1}"
      end

      @items.each do |f_or_f|
        out["orderedItems"].push f_or_f.contact.actor
      end

      content_type ActivityStream::ACTIVITY_TYPE
      out.to_json
    else
      erb :index
    end
  end

private
  def find_items
    @items = @user.send(@ar_collection).includes(:contact).order("id").
      limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
  end
end
