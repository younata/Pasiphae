module FeedService
  def articles(user, feed, date)
    if date.nil?
      feed.articles.joins(:user_articles)
        .where('user_articles.user_id = ?', user.id)
        .order(published: :desc).limit(20)
    else
      feed.articles.joins(:user_articles)
        .where('user_articles.user_id = ? AND (updated > ? OR published > ? OR user_articles.updated_at > ?)', user.id, date, date, date)
        .order(published: :desc)
    end
  end

  def batch_articles(user, feeds)
    ret = {}
    feeds.each do |feed, date|
      ret = ret.merge({feed => FeedService.articles(user, feed, date)})
    end
    ret
  end

  def articles_json(user, articles)
    articles.map do |article|
      user_article = article.user_articles.find_by(user: user)
      if user_article.nil?
        user.articles << article
        user_article = article.user_articles.find_by(user: user)
      end
      json = article.as_json(include: { :authors => { except: [:id, :article_id]}}, except: [:id, :feed_id, :created_at, :updated_at])
      json['read'] = user_article.read
      json
    end
  end
end