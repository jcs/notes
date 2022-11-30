class AddContactLd < ActiveRecord::Migration[5.2]
  def change
    add_column :contacts, :foreign_object_json, :text
  end
end
