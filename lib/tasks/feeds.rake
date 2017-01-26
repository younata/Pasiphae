namespace :feeds do
  desc 'update all feeds'
  task :update => :environment do
    require 'feed_helper'
    include FeedHelper

    update_all_feeds
  end
end
