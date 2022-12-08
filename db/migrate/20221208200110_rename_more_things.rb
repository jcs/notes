class RenameMoreThings < ActiveRecord::Migration[5.2]
  def change
    rename_column :contacts, :foreign_object_json, :object
    change_column :contacts, :object, :json
  end
end
