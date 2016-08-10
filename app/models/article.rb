class Article < ActiveRecord::Base
  belongs_to :feed
  has_and_belongs_to_many :authors
  has_many :user_articles
  has_many :users, through: :user_articles

  validates :feed, presence: true
  validates :published, presence: true
  validates :title, presence: true
  validates :url, presence: true, uniqueness: { case_sensitive: false }, url: true
end
