class ContactNotesController < ApplicationController
  self.path = "#{App.base_path}/from"

  PER_PAGE = 20
  EVERYONE = "everyone"
  TIMELINE = "timeline"

  get "/:address" do
    find_contact
    find_pages
    @notes = @scope.order("id DESC").limit(PER_PAGE)
    @page = 1
    erb :index
  end

  get "/:address/page/:page" do
    find_contact
    find_pages

    @page = params[:page].to_i
    if @page < 1 || @page > @pages
      halt 404, "no such page"
    end

    @notes = @scope.order("id DESC").limit(PER_PAGE).
      offset((@page - 1) * PER_PAGE)
    erb :index
  end

  get "/:address/:id" do
    find_contact
    find_note

    if ActivityStream.is_for_request?(request)
      content_type ActivityStream::ACTIVITY_TYPE
      @note.activitystream_object.to_json
    else
      last_modified (@note.note_modified_at || @note.created_at)
      erb :show
    end
  end

private
  def find_contact
    case params[:address]
    when TIMELINE
      @scope = @user.notes_from_followed.where(:is_public => true)
      @title = "Notes from timeline"
    when EVERYONE
      @scope = Note.where(:is_public => true).order("created_at DESC")
      @title = "Notes from everyone"
    else
      @contact = Contact.where(:address => params[:address]).first
      if !@contact
        halt 404, "no such contact"
      end
      @scope = @contact.notes
      @title = "Notes from #{@contact.address}"
    end
  end

  def find_pages
    @count = @scope.count
    @pages = (@count.to_f / PER_PAGE.to_f).ceil
    @base_url = "#{App.base_url}/from/#{params[:address]}"
  end

  def find_note
    note_id = params[:id]
    unless note_id then halt 404, "no note id" end

    @note = @scope.where(:id => note_id).first
    unless @note then halt 404, "no such note" end
  end
end
