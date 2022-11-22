class Following < DBModel
  belongs_to :user
  belongs_to :contact
end
