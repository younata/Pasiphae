class Feed < ActiveRecord::Base
  has_and_belongs_to_many :users
  has_many :articles

  validates :url, presence: true, uniqueness: { case_sensitive: false }, url: true
end
