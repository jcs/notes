class AttachmentsController < ApplicationController
  self.path = "#{App.base_path}/attachments"

  get "/:id" do
    attachment = Attachment.where(:id => params[:id]).first
    unless attachment then halt 404, "no such attachment" end

    content_type attachment.type
    last_modified (attachment.note.note_modified_at ||
      attachment.note.created_at)
    expires 1.month, :public, :must_revalidate
    attachment.blob.data
  end
end
