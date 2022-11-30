class User < DBModel
  has_many :followings,
    :dependent => :destroy
  has_many :followers,
    :dependent => :destroy
  has_one :contact,
    :dependent => :destroy
  has_many :notes,
    :through => :contact
  has_many :api_tokens,
    :dependent => :destroy

  has_secure_password

  before_create :create_contact_and_keys

  include UserActivityStream

  def self.find_by_address(address)
    m = address.match(/\A([^@]+)@(.+)\z/)
    if !m
      return nil
    end

    if m[2] != App.domain
      return nil
    end

    User.where(:username => m[1]).first
  end

  def address
    "#{self.username}@#{App.domain}"
  end

  def following?(actor)
    self.followings.joins(:contact).where("contacts.actor = ?", actor).any?
  end

  def followed_by?(actor)
    self.followers.joins(:contact).where("contacts.actor = ?", actor).any?
  end

  def timeline
    Note.where(:contact_id => self.followings.pluck(:contact_id)).
      includes(:contact).where(:is_public => true)
  end

private
  def create_contact_and_keys
    key = OpenSSL::PKey::RSA.new(2048)
    self.private_key = key.to_s

    c = self.build_contact
    c.actor = App.base_url
    c.address = self.address
    c.key_id = self.activitystream_key_id
    c.key_pem = key.public_key
    c.inbox = self.activitystream_inbox_url
    c.url = self.activitystream_url
    c.save!
  end
end
