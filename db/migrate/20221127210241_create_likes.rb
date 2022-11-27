class CreateLikes < ActiveRecord::Migration[5.2]
  def change
    create_table :likes do |t|
      t.datetime :created_at, :null => false
      t.integer :contact_id
      t.integer :note_id
    end

    add_index :likes, [ :note_id, :contact_id ], :unique => true
  end
end
