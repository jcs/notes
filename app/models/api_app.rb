class ApiApp < DBModel
  has_many :api_tokens,
    :dependent => :destroy

  validates_presence_of :client_name, :redirect_uri, :scopes

  before_create :assign_client_id_and_secret

  REDIRECT_OOB = "urn:ietf:wg:oauth:2.0:oob"

  def self.can_request_scopes?(our_scopes, want_scopes)
    our_scopes = Hash[our_scopes.split(" ").map{|z| [ z, true ] }]

    want_scopes.split(" ").each do |z|
      if !our_scopes[z]
        return false
      end
    end

    true
  end

  def can_request_scopes?(r_scopes)
    ApiApp.can_request_scopes?(self.scopes, r_scopes)
  end

  def scopes_h
    Hash[self.scopes.split(" ").map{|z| [ z, true ] }]
  end

private
  def assign_client_id_and_secret
    self.client_id = SecureRandom.safe(64)
    self.client_secret = SecureRandom.safe(64)
  end
end
