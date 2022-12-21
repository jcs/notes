class CreateNotifications < ActiveRecord::Migration[5.2]
  def change
    create_table :notifications do |t|
      t.datetime :created_at
      t.string :type
      t.integer :user_id
      t.integer :note_id
      t.integer :contact_id
    end

    add_index :notifications, [ :user_id, :note_id, :contact_id, :type ],
      :unique => true, :name => "unique_notifications"
  end
end
