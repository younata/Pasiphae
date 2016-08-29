require 'resque'

class Api::V1::FeedsController < Api::V1::ApiController
  before_action :restrict_api_access

  def subscribe
    feeds_list = params['feeds']
    feeds_list.each do |url|
      feed = Feed.find_by(url: url)
      unless feed
        feed = Feed.create(url: url)
        feed.save
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

  def fetch
    feeds = []
    feeds_specified = []
    use_old_lastupdated_behavior = true
    if params['feeds']
      use_old_lastupdated_behavior = false

      params['feeds'].each do |key, value|
        date = DateTime.parse(value)
        if date
          feed = @user.feeds.find_by(url: key)
          hash = feed.as_json(except: [:id, :created_at, :updated_at])
          articles = feed.articles.where("updated_at > ?", date).order(published: :desc).as_json(include: { :authors => { except: [:id, :article_id]}}, except: [:id, :feed_id, :created_at, :updated_at])
          hash[:articles] = articles
          hash[:last_updated] = feed.updated_at
          feeds << hash
          feeds_specified << feed.url
        end
      end
    end
    if params['date'] and DateTime.parse(params['date'])
      date = DateTime.parse(params['date'])
      feeds += @user.feeds.select { |f| !feeds_specified.include?(f.url) }.map do |feed|
        hash = feed.as_json(except: [:id, :created_at, :updated_at])
        articles = feed.articles.where("updated_at > ?", date).order(published: :desc).as_json(include: { :authors => { except: [:id, :article_id]}}, except: [:id, :feed_id, :created_at, :updated_at])
        hash[:articles] = articles
        unless use_old_lastupdated_behavior
          hash[:last_updated] = feed.updated_at
        end
        hash
      end
    else
      feeds += @user.feeds.select { |f| !feeds_specified.include?(f.url) }.map do |feed|
        hash = feed.as_json(except: [:id, :created_at, :updated_at])
        articles = feed.articles.order(published: :desc).limit(20).as_json(include: { :authors => { except: [:id, :article_id]}}, except: [:id, :feed_id, :created_at, :updated_at])
        hash[:articles] = articles
        unless use_old_lastupdated_behavior
          hash[:last_updated] = feed.updated_at
        end
        hash
      end
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
