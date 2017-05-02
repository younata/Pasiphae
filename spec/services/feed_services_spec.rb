require 'rails_helper'
require 'feed_service'
include FeedService

RSpec.describe FeedService, type: :service do
  describe 'articles(user,feed,date)' do
    let(:user) do
      User.create(email: 'user@example.com', password: 'password', password_confirmation: 'password')
    end

    let(:feed) do
      Feed.create(url: 'https://example.com/1')
    end

    let(:old_article) do
      article = Article.create(title: 'old2', updated: 15.seconds.ago, published: 20.seconds.ago, url: 'https://example.com/old_2', feed: feed, content: 'this is an old article')
      user.articles << article
      user_article = article.user_articles.first
      user_article.updated_at = article.published
      user_article.save
      article
    end

    let(:old_article_2) do
      article = Article.create(title: 'old3', updated: 8.seconds.ago, published: 20.seconds.ago, url: 'https://example.com/old_3', feed: feed, content: 'this is an old article')
      user.articles << article
      user_article = article.user_articles.first
      user_article.updated_at = article.published
      user_article.save
      article
    end

    let(:new_article) do
      article = Article.create(title: 'new2', published: 3.seconds.ago, url: 'https://example.com/new_2', feed: feed, content: 'this is a new article')
      user.articles << article
      user_article = article.user_articles.first
      user_article.updated_at = article.published
      user_article.save
      article
    end

    let(:new_article_2) do
      article = Article.create(title: 'new3', published: 3.seconds.ago, updated: 3.seconds.ago, url: 'https://example.com/new_3', feed: feed, content: 'this is a new article')
      user.articles << article
      user_article = article.user_articles.first
      user_article.updated_at = 0.seconds.ago
      user_article.save
      article
    end

    let(:extra_articles) do
      articles = create_list(:article, 19, feed: feed, updated: 4.seconds.ago, published: 5.seconds.ago)
      articles.each do |article|
        user.articles << article
        user_article = article.user_articles.first
        user_article.updated_at = article.published
        user_article.save
      end
      articles
    end

    before do
      user.feeds << feed
      feed.articles << [old_article, old_article_2, new_article, new_article_2, *extra_articles]
    end

    it 'returns the list of articles for a feed since the given date' do
      articles = FeedService.articles(user, feed, 6.seconds.ago)
      expect(articles).to include(*extra_articles, new_article_2, new_article)
      expect(articles).to_not include(old_article, old_article_2)
    end

    it 'includes old articles in that list if they have been updated them since the date given' do
      articles = FeedService.articles(user, feed, 10.seconds.ago)
      expect(articles).to include(*extra_articles, old_article_2, new_article_2, new_article)
      expect(articles).to_not include(old_article)
    end

    it 'includes articles in that list if the user has done something to them since the date given' do
      articles = FeedService.articles(user, feed, 2.seconds.ago)
      expect(articles).to include(new_article_2)
      expect(articles).to_not include(old_article, *extra_articles, old_article_2, new_article)
    end

    it 'returns the 20 most recent articles when given a nil date' do
      articles = FeedService.articles(user, feed, nil)
      expect(articles).to include(new_article, new_article_2)
      expect(articles.count).to eq(20)

      expect(articles).to include(*(extra_articles.first(18)))
      expect(articles).to_not include(old_article, old_article_2)
    end
  end

  describe 'batch_articles' do
    let(:user) do
      User.create(email: 'user@example.com', password: 'password', password_confirmation: 'password')
    end

    let(:feed) do
      Feed.create(url: 'https://example.com/1')
    end

    let(:feed_2) do
      Feed.create(url: 'https://example.com/2')
    end

    it 'utilizes :articles to return feeds by the given date' do
      feed_update_time = 10.seconds.ago
      feed_2_update_time = 20.seconds.ago
      allow(FeedService).to receive(:articles).with(user, feed, feed_update_time).and_return([0, 1, 2, 3])
      allow(FeedService).to receive(:articles).with(user, feed_2, feed_2_update_time).and_return([10, 11, 12, 13])

      received = Feed.batch_articles(user, {feed => feed_update_time, feed_2 => feed_2_update_time})

      expected = {
        feed => [0, 1, 2, 3],
        feed_2 => [10, 11, 12, 13]
      }
      expect(received).to eq(expected)
    end
  end

  describe 'article_json' do
    let(:feed) do
      Feed.create(url: 'https://example.com/1')
    end

    let(:article) do
      Article.create(
        title: 'new',
        published: 1.seconds.ago,
        url: 'https://example.com/new',
        content: 'this is a new article',
        summary: 'a summary',
        updated: 0.seconds.ago,
        feed: feed
      )
    end

    let(:article_2) do
      Article.create(
        title: 'new_2',
        published: 1.seconds.ago,
        url: 'https://example.com/new_2',
        content: 'this is a new article 2',
        feed: feed
      )
    end

    let(:user) do
      User.create(email: 'user@example.com', password: 'password', password_confirmation: 'password')
    end

    let(:author) do
      Author.create(name: 'foo')
    end

    let(:author_2) do
      Author.create(name: 'bar')
    end

    before do
      article.authors << author
      article_2.authors << author
      article_2.authors << author_2

      [article, article_2].each do |item|
        user.articles << item
        user_article = item.user_articles.first
        user_article.updated_at = 0.seconds.ago
        user_article.save
      end

      item = article.user_articles.first
      item.read = true
      item.save
      user.save
    end

    it 'parses the articles and their authors into a json hash' do
      expected = JSON.parse(JSON.dump([
        {
          'title': 'new',
          'url': 'https://example.com/new',
          'summary': 'a summary',
          'published': article.published,
          'updated': article.updated,
          'content': 'this is a new article',
          'authors': [{'name': 'foo', 'email': nil}],
          'read': true
        },
        {
          'title': 'new_2',
          'url': 'https://example.com/new_2',
          'summary': nil,
          'published': article_2.published,
          'updated': nil,
          'content': 'this is a new article 2',
          'authors': [{'name': 'foo', 'email': nil}, {'name': 'bar', 'email': nil}],
          'read': false
        }
      ]))

      json = FeedService.articles_json(user, [article, article_2])

      expect(JSON.parse(JSON.dump(json))).to eq(expected)
    end
  end
end