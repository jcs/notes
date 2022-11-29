class AddApiApps < ActiveRecord::Migration[5.2]
  def change
    create_table :api_apps do |t|
      t.string :client_name
      t.string :redirect_uri
      t.string :scopes
      t.string :website
      t.string :client_id
      t.string :client_secret
      t.string :vapid_key
    end

    add_index :api_apps, [ :client_id ], :unique => true
  end
end
