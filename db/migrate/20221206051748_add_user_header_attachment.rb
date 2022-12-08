class AddUserHeaderAttachment < ActiveRecord::Migration[5.2]
  def change
    add_column :contacts, :header_attachment_id, :integer
  end
end
