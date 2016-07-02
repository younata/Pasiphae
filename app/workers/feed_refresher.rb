require 'feed_helper'

class FeedRefresher
  def self.perform()
    update_all_feeds
  end
end
