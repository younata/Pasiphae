class User < ActiveRecord::Base
  has_many :user_articles
  has_many :articles, through: :user_articles

  after_create :add_device

  has_secure_password
  has_many :devices, dependent: :destroy
  has_and_belongs_to_many :feeds

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :password, presence: true

private

  def add_device
    self.devices.create(user: self)
  end
end
