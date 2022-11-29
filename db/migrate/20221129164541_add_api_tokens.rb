class AddApiTokens < ActiveRecord::Migration[5.2]
  def change
    create_table "api_tokens" do |t|
      t.timestamps
      t.integer :api_app_id
      t.integer :user_id
      t.string :scope
      t.string :code
      t.string :access_token
    end
    add_index :api_tokens, [ :access_token ], :unique => true
  end
end
