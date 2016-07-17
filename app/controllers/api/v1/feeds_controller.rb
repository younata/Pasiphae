require 'resque'

class Api::V1::FeedsController < Api::V1::ApiController
  before_filter :restrict_api_access

  def subscribe
    feeds_list = params['feeds']
    feeds_list.each do |url|
      feed = Feed.find_by(url: url)
      unless feed
        feed = Feed.create(url: url)
        feed.save
        FeedRefresher.perform(feed)
        #Resque.enqueue(FeedRefresher, feed)
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

  def fetch
    feeds = nil
    if params['date'] and DateTime.parse(params['date'])
      date = DateTime.parse(params['date'])
      feeds = @user.feeds.map do |feed|
        hash = feed.as_json(except: [:id, :created_at, :updated_at])
        articles = feed.articles.where("published > ? OR updated > ?", date, date).order(published: :desc).as_json(include: { :authors => { except: [:id, :article_id]}}, except: [:id, :feed_id])
        hash[:articles] = articles
        hash
      end
    else
      feeds = @user.feeds.map do |feed|
        hash = feed.as_json(except: [:id, :created_at, :updated_at])
        articles = feed.articles.order(published: :desc).as_json(include: { :authors => { except: [:id, :article_id]}}, except: [:id, :feed_id])
        hash[:articles] = articles
        hash
      end
    end
    last_updated_article = Article.order(updated: :desc, published: :desc).first

    if last_updated_article.nil?
      last_updated = Time.now
    else
      last_updated = last_updated_article.updated
      if last_updated.nil?
        last_updated = last_updated_article.published
      end
    end
    render json: {last_updated: last_updated, feeds: feeds}
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
