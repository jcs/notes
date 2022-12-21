class Forward < DBModel
  belongs_to :note
  belongs_to :contact

  after_create :create_notification

  def create_notification
    if self.note.local?
      Notification.create_for!(self)
    end
  end
end
