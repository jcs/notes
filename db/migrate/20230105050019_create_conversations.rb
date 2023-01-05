class CreateConversations < ActiveRecord::Migration[5.2]
  def change
    create_table :conversations do |t|
      t.string :public_id
    end
    add_index :conversations, [ :public_id ]

    add_column :notes, :conversation_id, :integer
    add_index :notes, [ :conversation_id ]

    Note.find_each do |n|
      if c = Conversation.where(:public_id => n.conversation).first
        n.conversation_id = c.id
      else
        c = Conversation.new
        c.public_id = n.conversation
        c.save!
        n.conversation_id = c.id
      end
      n.update_column(:conversation_id, n.conversation_id)
    end

    remove_column :notes, :conversation
  end
end
