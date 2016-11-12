require 'resque'
require 'feed_helper'
include FeedHelper

class Api::V1::FeedsController < Api::V1::ApiController
  before_action :restrict_api_access
  before_action :restrict_api_access, only: [:subscribe, :unsubscribe, :fetch, :feeds]

  def check
    url = params['url']
    unless url.nil?
      is_feed = FeedHelper::is_feed?(url)
      unless is_feed.nil?
        render json: {:feed => url, :opml => nil}
      else
        render json: {:feed => nil, :opml => FeedHelper::is_opml?(url)}
      end
    else
      head(204)
    end
  end

  def subscribe
    feeds_list = params['feeds']
    feeds_list.select {|url| FeedHelper::is_feed?(url)}.each do |url|
      feed = Feed.find_by(url: url)
      unless feed
        feed = Feed.create(url: url)
        FeedRefresher.perform(feed)
      end
      unless @user.feeds.exists?(feed.id)
        @user.feeds << feed
      end
    end
    render json: @user.feeds.map {|f| f.url}
  end

  def unsubscribe
    feeds_list = params['feeds']
    feeds_to_delete = feeds_list.map { |url| @user.feeds.find_by(url: url) }.compact
    @user.feeds.delete(feeds_to_delete)
    render json: @user.feeds.map {|f| f.url}
  end

  def feeds
    render json: @user.feeds.map {|f| f.url}
  end

  def fetch
    feeds = []
    feeds_specified = []
    use_old_lastupdated_behavior = true
    if params['feeds']
      use_old_lastupdated_behavior = false

      JSON.parse(params['feeds']).each do |key, value|
        date = DateTime.parse(value)
        if date
          feed = @user.feeds.find_by(url: key)
          unless feed.nil?
            hash = feed.as_json(except: [:id, :created_at, :updated_at])
            articles = feed.articles.joins(:user_articles).where("updated > ? OR published > ? OR user_articles.updated_at > ?", date, date, date).order(published: :desc)
            articles_json = articles.map do |article|
              user_article = article.user_articles.find_by(user: @user)
              if user_article.nil?
                @user.articles << article
                user_article = article.user_articles.find_by(user: @user)
              end
              json = article.as_json(include: { :authors => { except: [:id, :article_id]}}, except: [:id, :feed_id, :created_at, :updated_at])
              json[:read] = user_article.read
              json
            end
            hash[:articles] = articles_json
            article = articles.first
            if article.nil?
              hash[:last_updated] = feed.updated_at
            else
              hash[:last_updated] = article.published
            end
            feeds << hash
            feeds_specified << feed.url
          end
        end
      end
    end
    feeds += @user.feeds.where.not(url: feeds_specified).map do |feed|
      hash = feed.as_json(except: [:id, :created_at, :updated_at])
      articles = feed.articles.joins(:user_articles).order(published: :desc).limit(20)
      articles_json = articles.map do |article|
        user_article = article.user_articles.find_by(user: @user)
        if user_article.nil?
          @user.articles << article
          user_article = article.user_articles.find_by(user: @user)
        end
        json = article.as_json(include: { :authors => { except: [:id, :article_id]}}, except: [:id, :feed_id, :created_at, :updated_at])
        json[:read] = user_article.read
        json
      end
      hash[:articles] = articles_json
      article = articles.first
      if article.nil?
        hash[:last_updated] = feed.updated_at
      else
        hash[:last_updated] = article.published
      end
      hash
    end

    json_to_render = {feeds: feeds}

    if use_old_lastupdated_behavior
      last_updated_feed = Feed.order(updated_at: :asc).first

      if last_updated_feed.nil?
        last_updated = Time.now
      else
        last_updated = last_updated_feed.updated_at
      end
      json_to_render[:last_updated] = last_updated
    end
    render json: json_to_render
  end

private

  def restrict_api_access
    authenticate_or_request_with_http_token do |token, options|
      if Device.exists?(api_token: token)
        @device = Device.find_by(api_token: token)
        @user = @device.user
        true
      else
        false
      end
    end
  end
end
