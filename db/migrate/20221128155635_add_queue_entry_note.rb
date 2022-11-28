class AddQueueEntryNote < ActiveRecord::Migration[5.2]
  def change
    add_column :queue_entries, :note_id, :integer
    add_index :queue_entries, [ :note_id ]
  end
end
