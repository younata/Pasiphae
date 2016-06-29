class User < ActiveRecord::Base
  after_create :add_device

  has_secure_password
  has_many :devices, dependent: :destroy

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :password, presence: true

private

  def add_device
    self.devices.create(user: self)
  end
end
