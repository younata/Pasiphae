require 'csv'

class StatusBoardControllerController < ApplicationController
  before_action :restrict_access

  def current
    csv_text = CSV.generate do |csv|
      csv << ['75%', '25%']
      csv << ['Users', User.count]
      csv << ['Feeds', Feed.count]
      csv << ['Average Feeds/User', avg_feed_user]
      csv << ['Highest Feeds/User', max_feed_user]
      csv << ['Articles', Article.count]
      csv << ['Authors', Author.count]
    end
    render body: csv_text, content_type: 'text/csv'
  end

  def popular
    head :ok
  end

  def usage
    head :ok
  end

private

  def restrict_access
    authenticate_or_request_with_http_basic do |username, password|
      username == ENV['PASIPHAE_ADMIN'] && password == ENV['PASIPHAE_ADMIN_PW']
    end
  end

  def avg_feed_user
    feed_count = 0.0
    User.find_each do |user|
      feed_count += user.feeds.count
    end
    feed_count / User.count
  end

  def max_feed_user
    max_feed = 0
    User.find_each do |user|
      max_feed = [user.feeds.count, max_feed].max
    end
    max_feed
  end
end
