class Conversation < DBModel
  has_many :notes

  before_create :assign_public_id_for_local

  attr_accessor :is_local

private
  def assign_public_id_for_local
    if self.is_local
      self.id = UniqueId.get
      self.public_id = "#{App.base_url}/threads/#{self.id}"
    end
  end
end
