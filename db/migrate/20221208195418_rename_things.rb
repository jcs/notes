class RenameThings < ActiveRecord::Migration[5.2]
  def change
    rename_column :notes, :foreign_object_json, :object
    change_column :notes, :object, :json

    rename_column :queue_entries, :object_json, :object
    change_column :queue_entries, :object, :json

    add_column :notes, :for_timeline, :boolean, :default => false
    add_index :notes, [ :for_timeline ]

    Note.transaction do
      Note.find_each do |n|
        n.update_columns({
          :for_timeline => n.is_public,
          :is_public => true,
        })
      end
    end
  end
end
