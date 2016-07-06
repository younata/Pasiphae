require 'feed_helper'
include FeedHelper


class FeedRefresher
  def self.perform()
    update_all_feeds
  end
end
