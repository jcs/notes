class AddNotePublicId < ActiveRecord::Migration[5.2]
  def change
    remove_column :notes, :foreign_id
    add_column :notes, :public_id, :string
    add_index :notes, [ :public_id ], :unique => true
  end
end
