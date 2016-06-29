class Device < ActiveRecord::Base
  before_create :generate_api_token

  belongs_to :user

  validates :user, presence: true

private

  def generate_api_token
    begin
      self.api_token = SecureRandom.hex
    end while self.class.exists?(api_token: api_token)
  end
end
