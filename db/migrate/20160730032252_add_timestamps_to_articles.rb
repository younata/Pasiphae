class AddTimestampsToArticles < ActiveRecord::Migration
  def change
    add_timestamps :articles
  end
end
