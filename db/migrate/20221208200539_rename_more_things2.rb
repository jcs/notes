class RenameMoreThings2 < ActiveRecord::Migration[5.2]
  def change
    change_column :followers, :follow_object, :json
    change_column :followings, :follow_object, :json
  end
end
