require 'resque'
require 'feed_helper'
require 'feed_service'
include FeedHelper
include FeedService

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
      if feed.nil?
        feed = Feed.create(url: url)
        FeedRefresher.perform(feed)
        @user.feeds << feed
      elsif !@user.feeds.exists?(feed.id)
        @user.feeds << feed
        @user.articles << feed.articles
      end
      @user.save
    end
    render json: @user.feeds.map {|f| f.url}
  end

  def unsubscribe
    feeds_list = params['feeds']
    feeds_to_delete = feeds_list.map { |url| @user.feeds.find_by(url: url) }.compact
    @user.feeds.delete(feeds_to_delete)
    @user.articles.delete(feeds_to_delete.map { |f| f.articles })
    render json: @user.feeds.map {|f| f.url}
  end

  def feeds
    render json: @user.feeds.map {|f| f.url}
  end

  def fetch
    feeds = []
    feeds_specified = []
    if params['feeds']
      JSON.parse(params['feeds']).each do |key, value|
        date = DateTime.parse(value)
        feed = @user.feeds.find_by(url: key)
        unless feed.nil?
          hash = feed.as_json(except: [:id, :created_at, :updated_at])
          articles = FeedService.articles(@user, feed, date)
          hash[:articles] = FeedService.articles_json(@user, articles)
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
    feeds += @user.feeds.where.not(url: feeds_specified).map do |feed|
      hash = feed.as_json(except: [:id, :created_at, :updated_at])
      articles = FeedService.articles(@user, feed, nil)
      hash[:articles] = FeedService.articles_json(@user, articles)
      article = articles.first
      if article.nil?
        hash[:last_updated] = feed.updated_at
      else
        hash[:last_updated] = article.published
      end
      hash
    end

    json_to_render = {feeds: feeds}

    render json: json_to_render
  end

  MAX_NUMBER_OF_ARTICLES = 10
  def articles
    feed_url = params['feed']
    if feed_url.nil?
      head(204)
    else
      unless Feed.exists?(url: feed_url)
        return head(204)
      end
      page = (params['page'] || 1).to_i
      offset = (page - 1) * MAX_NUMBER_OF_ARTICLES

      articles = Feed.find_by(url: feed_url).articles.order(published: :desc).limit(MAX_NUMBER_OF_ARTICLES).offset(offset)

      @device = authenticate_with_http_token { |t, o| Device.find_by(api_token: t) }
      if @device.nil?
        @user = nil
      else
        @user = @device.user
        if @user.feeds.exists?(url: feed_url)
          articles = articles.joins(:user_articles).where('user_articles.user_id = ?', @user.id)
        else
          @user = nil
        end
      end


      articles_hash = articles.map do |article|
        json = article.as_json(include: { :authors => { except: [:id, :article_id]}}, except: [:id, :feed_id, :created_at, :updated_at])
        if @user.nil?
          json[:read] = false
        else
          user_article = article.user_articles.find_by(user_id: @user.id)
          json[:read] = user_article.read
        end
        json
      end

      render json: {articles: articles_hash}
    end
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
