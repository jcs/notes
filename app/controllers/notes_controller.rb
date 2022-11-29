class NotesController < ApplicationController
  self.path = App.base_path

  PER_PAGE = 20

  before do
    @count = @user.contact.notes.timeline.count
    @pages = (@count.to_f / PER_PAGE.to_f).ceil
    @base_url = @user.activitystream_url
  end

  get "/(.:format)?" do
    if ActivityStream.is_for_request?(request) || params[:format] == "json"
      content_type ActivityStream::ACTIVITY_TYPE
      @user.activitystream_object.to_json
    elsif !params[:format].blank?
      halt 404
    else
      @notes = @user.contact.notes.timeline.limit(PER_PAGE)
      likes = Like.where(:note_id => @notes.map{|n| n.id }).group(:note_id).
        count
      replies = Note.where(:parent_note_id => @notes.map{|n| n.id }).
        group(:parent_note_id).count
      forwards = Forward.where(:note_id => @notes.map{|n| n.id }).
        group(:note_id).count
      @notes.each do |n|
        n.like_count = likes[n.id].to_i
        n.reply_count = replies[n.id].to_i
        n.forward_count = forwards[n.id].to_i
      end
      @page = 1
      erb :index
    end
  end

  get "/page/:page" do
    @page = params[:page].to_i
    if @page < 1 || @page > @pages
      halt 404
    end

    @notes = @user.notes.timeline.order("id DESC").limit(PER_PAGE).
      offset((@page - 1) * PER_PAGE)
    erb :index
  end

  get "/:id" do
    find_note
    if ActivityStream.is_for_request?(request)
      content_type ActivityStream::ACTIVITY_TYPE
      @note.activitystream_object.to_json
    else
      last_modified (@note.note_modified_at || @note.created_at)
      erb :show
    end
  end

  get "/:id/likes" do
    find_note
    erb :likes
  end

  get "/:id/forwards" do
    find_note
    erb :forwards
  end

private
  def find_note
    note_id = params[:id]
    unless note_id then halt 404 end

    @note = Note.where(:id => note_id).first
    unless @note then halt 404 end
  end
end
