class Article < ActiveRecord::Base
  belongs_to :feed
  has_and_belongs_to_many :authors

  validates :feed, presence: true
  validates :published, presence: true
  validates :title, presence: true
  validates :url, presence: true, uniqueness: { case_sensitive: false }, url: true
end
