class Follower < DBModel
  belongs_to :user
  belongs_to :contact

  after_create :create_notification

  def create_notification
    Notification.create_for!(self)
  end
end
