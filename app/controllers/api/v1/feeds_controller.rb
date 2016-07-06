class Api::V1::FeedsController < Api::V1::ApiController
  before_filter :restrict_api_access

  def subscribe
    feeds_list = params['feeds']
    feeds_list.each do |url|
      feed = Feed.find_by(url: url)
      unless feed
        feed = Feed.create(url: url)
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
    if params['date'] and DateTime.parse(params['date'])
      date = DateTime.parse(params['date'])
      feeds = @user.feeds.map do |feed|
        hash = feed.as_json(except: [:id, :created_at, :updated_at])
        articles = feed.articles.where("published > ? OR updated > ?", date, date).as_json(include: { :authors => { except: [:id, :article_id]}}, except: [:id, :feed_id])
        hash[:articles] = articles
        hash
      end
      render json: feeds
    else
      json_args = {include: { :articles => { include: { :authors => { except: [:id, :article_id]}}, except: [:id, :feed_id]}}, except: [:id, :created_at, :updated_at]}
      render json: @user.feeds.to_json(json_args)
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
