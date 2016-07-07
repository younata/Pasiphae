require 'feed_helper'
include FeedHelper


class FeedRefresher
  @queue = :feed_refresher
  def self.perform(feed=nil)
    if feed.nil?
      update_all_feeds
    else
      update_rss_feed(feed)
    end
  end
end
