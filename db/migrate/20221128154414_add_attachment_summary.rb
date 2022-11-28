class AddAttachmentSummary < ActiveRecord::Migration[5.2]
  def change
    add_column :attachments, :summary, :string

    rename_column :notes, :foreign_object, :foreign_object_json
  end
end
