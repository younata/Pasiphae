class Api::V1::ArticlesController < Api::V1::ApiController
  before_action :restrict_api_access

  def update
    #articles: { url: params.keys.to_a }
    urls = params['articles'].keys.to_a
    @user.user_articles.joins(:article).where(articles: {url: urls}).find_each do |user_article|
      user_article.read = params['articles'][user_article.article.url]
      user_article.save
    end
    head(:ok)
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
