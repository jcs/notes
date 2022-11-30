class AddNoteIsPublic < ActiveRecord::Migration[5.2]
  def change
    add_column :notes, :is_public, :boolean, :default => false
    add_index :notes, [ :is_public ]
  end
end
