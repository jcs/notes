class CreateTables < ActiveRecord::Migration[5.2]
  def change
    create_table :users do |t|
      t.timestamps
      t.string :username
      t.string :password_digest
      t.text :private_key
    end
    add_index :users, [ :username ], :unique => true

    execute("CREATE TABLE keystores (" +
      "\"key\" varchar PRIMARY KEY NOT NULL, " +
      "\"value\" varchar NOT NULL, " +
      "\"expiration\" datetime)")

    create_table :contacts do |t|
      t.timestamps
      t.integer :user_id
      t.string :actor
      t.string :key_id
      t.string :key_pem
      t.string :inbox
      t.string :url
      t.string :realname
      t.string :address
      t.text :about
      t.integer :avatar_attachment_id
    end
    add_index :contacts, [ :user_id ], :unique => true
    add_index :contacts, [ :actor ], :unique => true
    add_index :contacts, [ :key_id ], :unique => true
    add_index :contacts, [ :address ], :unique => true

    create_table :notes do |t|
      t.datetime :created_at, null: false
      t.datetime :note_modified_at
      t.integer :contact_id
      t.string :note
      t.integer :parent_note_id
      t.text :import_id
      t.string :conversation
      t.text :foreign_object
      t.string :foreign_id
    end
    add_index :notes, [ :contact_id ]
    add_index :notes, [ :import_id ], :unique => true
    add_index :notes, [ :parent_note_id ]
    add_index :notes, [ :conversation ]
    add_index :notes, [ :foreign_id ]

    create_table :attachments do |t|
      t.integer :note_id
      t.string :type
      t.integer :width
      t.integer :height
      t.integer :duration
      t.string :source
    end
    add_index :attachments, [ :note_id ]

    create_table :attachment_blobs do |t|
      t.integer :attachment_id
      t.binary :data
    end
    add_index :attachment_blobs, [ :attachment_id ]

    create_table :followings do |t|
      t.timestamps
      t.integer :user_id
      t.integer :contact_id
      t.text :follow_object
    end
    add_index :followings, [ :user_id, :contact_id ], :unique => true

    create_table :followers do |t|
      t.timestamps
      t.integer :user_id
      t.integer :contact_id
      t.text :follow_object
    end
    add_index :followers, [ :user_id, :contact_id ], :unique => true

    create_table :queue_entries do |t|
      t.timestamp :created_at
      t.timestamp :next_try_at
      t.integer :tries
      t.integer :user_id
      t.integer :contact_id
      t.string :action
      t.text :object_json
    end
    add_index :queue_entries, [ :contact_id ]
  end
end
