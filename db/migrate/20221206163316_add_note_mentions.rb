class AddNoteMentions < ActiveRecord::Migration[5.2]
  def change
    add_column :notes, :mentioned_contact_ids, :json
  end
end
