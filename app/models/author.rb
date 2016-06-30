class Author < ActiveRecord::Base
  has_and_belongs_to_many :articles

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
