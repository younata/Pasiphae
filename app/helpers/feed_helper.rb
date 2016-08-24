require 'rest-client'
require 'feedjira'

module FeedHelper
  def update_all_feeds
    Feed.find_each do |feed|
      begin
        update_rss_feed(feed)
      rescue Exception => e
        puts e
      end
    end
  end

  def update_rss_feed(feed)
    response = RestClient.get feed.url
    Feedjira::Feed.add_common_feed_element 'image'
    Feedjira::Feed.add_common_feed_element 'icon'
    channel = Feedjira::Feed.parse(response.body)
    feed.title = channel.title
    feed.summary = channel.description
    feed.image_url = channel.image || channel.icon

    channel.entries.each do |item|
      article = nil
      if feed.articles.exists?(url: item.url)
        article = feed.articles.find_by(url: item.url)
        article.title = item.title
        article.summary = item.summary
        article.updated = item.updated
        article.content = item.content
      elsif Article.exists?(url: item.url)
        article = Article.find_by(url: item.url)
        article.title = item.title
        article.summary = item.summary
        article.updated = item.updated
        article.content = item.content
        feed.articles << article
      else
        url = item.url
        unless item.url.start_with?('http://', 'https://')
          feed_uri = URI(feed.url)
          if url.start_with?('/')
            url.slice!(0)
          end
          url = "#{feed_uri.scheme}://#{feed_uri.host}/#{url}"
        end
        article = Article.create(title: item.title, url: url, summary: item.summary, published: item.published || DateTime.now, content: item.content, updated: item.updated, feed: feed)
        if not article.valid?
          puts "Article #{item.url} is invalid!"
          puts article.errors.details.inspect
        end
      end

      if item.author
        author = nil
        if Author.exists?(name: item.author)
          author = Author.find_by(name: item.author)
        else
          author = Author.create(name: item.author)
        end
        if !article.authors.exists?(id: author.id)
          article.authors << author
        end
        author.save
        end
      article.save
    end
    feed.touch
    feed.save
  end
end
