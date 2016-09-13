require 'rest-client'
require 'feedjira'
require 'uri'

module FeedHelper
  def is_feed?(url)
    uri = URI(url)
    unless ['http', 'https'].include? uri.scheme
      return false
    end
    if Feed.exists?(url: [url + '/', url.chomp('/')])
      return true
    else
      response = RestClient.get url
      return !Feedjira::Feed.determine_feed_parser_for_xml(response.body).nil?
    end
  end

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
      item_url = item.url
      unless item_url.start_with?('http://', 'https://')
        feed_uri = URI(feed.url)
        if item_url.start_with?('/')
          item_url.slice!(0)
        end
        item_url = "#{feed_uri.scheme}://#{feed_uri.host}/#{item_url}"
      end

      article = nil
      if feed.articles.exists?(url: item_url)
        article = feed.articles.find_by(url: item_url)
        article.title = item.title
        article.summary = item.summary
        article.updated = item.updated
        article.content = item.content
      elsif Article.exists?(url: item_url)
        article = Article.find_by(url: item_url)
        article.title = item.title
        article.summary = item.summary
        article.updated = item.updated
        article.content = item.content
        feed.articles << article
      else
        article = Article.create(title: item.title, url: item_url, summary: item.summary, published: item.published || DateTime.now, content: item.content, updated: item.updated, feed: feed)
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
