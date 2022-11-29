class ApiToken < DBModel
  belongs_to :api_app
  belongs_to :user

  validates_presence_of :api_app_id, :scope

  before_create :assign_code_and_access_token

  attr_accessor :email, :username, :client_id, :response_type, :redirect_uri

  def can_request_scopes?(r_scopes)
    ApiApp.can_request_scopes?(self.scope, r_scopes)
  end

private
  def assign_code_and_access_token
    self.code = SecureRandom.safe(64)
    self.access_token = SecureRandom.safe(64)
  end
end
