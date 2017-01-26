require 'rest-client'
require 'feedjira'
require 'uri'
require 'opml-parser'

include OpmlParser

module FeedHelper
  def is_feed?(url)
    uri = URI(url)
    unless ['http', 'https'].include? uri.scheme
      return nil
    end
    if Feed.exists?(url: [url + '/', url.chomp('/')])
      Feed.find_by(url: [url + '/', url.chomp('/')]).url
    else
      response = RestClient.get url
      if Feedjira::Feed.determine_feed_parser_for_xml(response.body).nil?
        nil
      else
        url
      end
    end
  end

  def is_opml?(url)
    uri = URI(url)
    unless ['http', 'https'].include? uri.scheme
      return nil
    end
    response = RestClient.get url
    opml_items = OpmlParser.import(response.body).map {|o| o.attributes}

    urls = opml_items.map do |item|
      xml_url_key = item.keys.find {|k| 'xmlurl' == k.to_s.downcase}
      unless xml_url_key.nil?
        item[xml_url_key]
      end
    end

    urls = urls.select { |o| !o.nil? && !o.empty? }
    if urls.empty?
      nil
    else
      urls
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
    puts "downloading #{feed.url}"
    past = Time.now
    response = RestClient.get feed.url
    Feedjira::Feed.add_common_feed_element 'image'
    Feedjira::Feed.add_common_feed_element 'icon'
    channel = Feedjira::Feed.parse(response.body)
    puts "downloaded #{feed.url}, took #{Time.now - past} seconds"
    update_feed_from_channel(channel, feed)
  end

private
  def update_feed_from_channel(channel, feed)
    past = Time.now
    feed.title = channel.title
    feed.summary = channel.description
    if channel.image.nil?
      feed.image_url = channel.icon
    else
      feed.image_url = channel.image.url
    end
    feed_users = feed.users

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
        if item.methods.include?(:updated)
          article.updated = item.updated
        end
        article.content = item.content
      elsif Article.exists?(url: item_url)
        article = Article.find_by(url: item_url)
        article.title = item.title
        article.summary = item.summary
        if item.methods.include?(:updated)
          article.updated = item.updated
        end
        article.content = item.content
        feed_users.each do |user|
          unless user.articles.include? article
            user.articles << article
          end
        end
        feed.articles << article
      else
        article = Article.create(title: item.title, url: item_url, summary: item.summary, published: item.published || DateTime.now, content: item.content, updated: item.updated, feed: feed)
        feed_users.each do |user|
          unless user.articles.include? article
            user.articles << article
          end
        end
        if not article.valid?
          puts "Article #{item.url} is invalid!"
          puts article.errors.details.inspect
        end
      end

      if item.author
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
    feed_users.each {|u| u.save}
    feed.touch
    feed.save
    now = Time.now
    puts "Updated #{feed.url}, took #{now - past} seconds"
  end

  def download_urls(feeds)
    output = []
    threads = []
    feeds.each do |feed|
      threads << Thread.new do
        begin
          puts "downloading #{feed.url}"
          past = Time.now
          response = RestClient::Request.execute(method: :get, url: feed.url, timeout: 10)
          # response = RestClient.get feed.url
          now = Time.now
          puts "downloaded #{feed.url}, took #{now - past} seconds"
          Feedjira::Feed.add_common_feed_element 'image'
          Feedjira::Feed.add_common_feed_element 'icon'
          output << [Feedjira::Feed.parse(response.body), feed]
        rescue Exception => e
          puts "Error downloading feed: #{e}"
        end
      end
    end
    threads.each { |t| t.join }
    output
  end
end
