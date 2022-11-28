class ContactNotesController < ApplicationController
  self.path = "#{App.base_path}/from"

  PER_PAGE = 20

  get "/:address" do
    find_contact
    find_pages
    @notes = @contact.notes.order("id DESC").limit(PER_PAGE)
    @page = 1
    erb :index
  end

  get "/:address/pages/:page" do
    find_contact
    find_pages

    @page = params[:page].to_i
    if @page < 1 || @page > @pages
      halt 404, "no such page"
    end

    @notes = @contact.notes.order("id DESC").limit(PER_PAGE).
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
    @contact = Contact.where(:address => params[:address]).first
    if !@contact
      halt 404, "no such contact"
    end
  end

  def find_pages
    @count = @contact.notes.count
    @pages = (@count.to_f / PER_PAGE.to_f).ceil
    @base_url = @user.activitystream_url
  end

  def find_note
    note_id = params[:id]
    unless note_id then halt 404, "no note id" end

    @note = @contact.notes.where(:id => note_id).first
    unless @note then halt 404, "no such note" end
  end
end
