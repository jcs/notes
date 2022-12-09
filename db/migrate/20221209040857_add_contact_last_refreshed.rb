class AddContactLastRefreshed < ActiveRecord::Migration[5.2]
  def change
    add_column :contacts, :last_refreshed_at, :datetime
  end
end
