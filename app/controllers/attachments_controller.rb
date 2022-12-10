class AttachmentsController < ApplicationController
  self.path = "#{App.base_path}/attachments"

  get "/:id" do
    attachment = Attachment.where(:id => params[:id]).first
    unless attachment then halt 404, "no such attachment" end

    if attachment.blob
      content_type attachment.type
      if attachment.note
        last_modified (attachment.note.note_modified_at ||
          attachment.note.created_at)
      end
      expires 1.month, :public, :must_revalidate
      attachment.blob.data
    elsif attachment.source.present?
      redirect attachment.source
    else
      halt 404
    end
  end
end
