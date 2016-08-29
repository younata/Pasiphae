require 'rails_helper'
require 'api_helper'

RSpec.describe Api::V1::FeedsController, type: :controller do
  describe "POST #subscribe" do
    it_behaves_like 'an api request' do
      before do
        post :subscribe
      end
    end

    describe 'with an application token' do
      before do
        request.headers['X-APP-TOKEN'] = 'GreatSuccess'
      end

      it_behaves_like 'an api requiring a user' do
        before do
          post :subscribe
        end
      end

      describe 'with an api token' do
        let!(:user) do
          u = User.new(email: 'user@example.com', password: 'password', password_confirmation: 'password')
          u.save
          u
        end

        before do
          allow(FeedRefresher).to receive(:perform)
          request.headers['Authorization'] = "Token token=\"#{user.devices.first.api_token}\""
        end

        describe 'and none of the feeds specified exist already' do
          before do
            post :subscribe, params: { :feeds => ['https://example.com/1', 'https://example.com/2'] }
          end

          it 'creates those feeds' do
            expect(Feed.all.count).to eq(2)
            expect(Feed.exists?(url: 'https://example.com/1')).to be_truthy
            expect(Feed.exists?(url: 'https://example.com/2')).to be_truthy
          end

          it 'enqueues a resque task to update each feed' do
            expect(FeedRefresher).to have_received(:perform).with(Feed.first)
            expect(FeedRefresher).to have_received(:perform).with(Feed.last)
          end

          it 'subscribes the user to those feeds' do
            expect(user.feeds.count).to eq(2)
            feed1 = Feed.find_by(url: 'https://example.com/1')
            feed2 = Feed.find_by(url: 'https://example.com/2')

            expect(user.feeds.exists?(feed1.id)).to be_truthy
            expect(user.feeds.exists?(feed2.id)).to be_truthy
          end

          it 'returns http 200' do
            expect(response).to have_http_status(:ok)
          end

          it 'returns the list of feeds the user is subscribed to' do
            json = JSON.parse(response.body)
            expect(json).to eq(['https://example.com/1', 'https://example.com/2'])
          end
        end

        describe 'and at least one of the feeds specified exists already' do
          let!(:feed) do
            f = Feed.new(url: 'https://example.com/1')
            f.save
            f
          end

          before do
            post :subscribe, params: { :feeds => ['https://example.com/1', 'https://example.com/2'] }
          end

          it 'creates only the unknown feeds' do
            expect(Feed.all.count).to eq(2)
            expect(Feed.exists?(url: 'https://example.com/1')).to be_truthy
            expect(Feed.exists?(url: 'https://example.com/2')).to be_truthy
          end

          it 'enqueues a resque task to update each new feed' do
            new_feed = Feed.find_by(url: 'https://example.com/2')
            expect(FeedRefresher).to have_received(:perform).with(new_feed)
            expect(FeedRefresher).to_not have_received(:perform).with(feed)
          end

          it 'subscribes the user to those feeds' do
            expect(user.feeds.count).to eq(2)
            feed2 = Feed.find_by(url: 'https://example.com/2')

            expect(user.feeds.exists?(feed.id)).to be_truthy
            expect(user.feeds.exists?(feed2.id)).to be_truthy
          end

          it 'returns http 200' do
            expect(response).to have_http_status(:ok)
          end

          it 'returns the list of feeds the user is subscribed to' do
            json = JSON.parse(response.body)
            expect(json).to eq(['https://example.com/1', 'https://example.com/2'])
          end
        end

        describe 'and the user is already subscribed to one of those feeds' do
          let!(:feed) do
            f = Feed.new(url: 'https://example.com/1')
            f.save
            f
          end

          before do
            user.feeds << feed
            user.save
            post :subscribe, params: { :feeds => ['https://example.com/1', 'https://example.com/2'] }
          end

          it 'creates only the unknown feeds' do
            expect(Feed.all.count).to eq(2)
            expect(Feed.exists?(url: 'https://example.com/1')).to be_truthy
            expect(Feed.exists?(url: 'https://example.com/2')).to be_truthy
          end

          it 'enqueues a resque task to update each new feed' do
            new_feed = Feed.find_by(url: 'https://example.com/2')
            expect(FeedRefresher).to have_received(:perform).with(new_feed)
            expect(FeedRefresher).to_not have_received(:perform).with(feed)
          end

          it 'subscribes the user to the feeds they haven\'t already subscribed to' do
            expect(user.feeds.count).to eq(2)
            feed2 = Feed.find_by(url: 'https://example.com/2')

            expect(user.feeds.exists?(feed.id)).to be_truthy
            expect(user.feeds.exists?(feed2.id)).to be_truthy
          end

          it 'returns http 200' do
            expect(response).to have_http_status(:ok)
          end

          it 'returns the list of feeds the user is subscribed to' do
            json = JSON.parse(response.body)
            expect(json).to eq(['https://example.com/1', 'https://example.com/2'])
          end
        end
      end
    end
  end

  describe "POST #unsubscribe" do
    it_behaves_like 'an api request' do
      before do
        post :unsubscribe
      end
    end

    describe 'with an application token' do
      before do
        request.headers['X-APP-TOKEN'] = 'GreatSuccess'
      end

      it_behaves_like 'an api requiring a user' do
        before do
          post :unsubscribe
        end
      end

      describe 'with an api token' do
        let!(:user) do
          u = User.new(email: 'user@example.com', password: 'password', password_confirmation: 'password')
          u.save
          u
        end

        before do
          request.headers['Authorization'] = "Token token=\"#{user.devices.first.api_token}\""
        end

        describe 'and the user is not subscribed to any of the specified feeds' do
          let!(:feed) do
            f = Feed.new(url: 'https://example.com/1')
            f.save
            f
          end

          let!(:feed2) do
            f = Feed.new(url: 'https://example.com/2')
            f.save
            f
          end

          before do
            user.feeds << feed
            user.save
            post :unsubscribe, params: { :feeds => ['https://example.com/2'] }
          end

          it 'returns http 200' do
            expect(response).to have_http_status(:ok)
          end

          it 'returns the list of feeds the user is subscribed to' do
            json = JSON.parse(response.body)
            expect(json).to eq(['https://example.com/1'])
          end
        end

        describe 'and the feed the user wishes to unsubscribe from does not exist' do
          let!(:feed) do
            f = Feed.new(url: 'https://example.com/1')
            f.save
            f
          end

          before do
            user.feeds << feed
            user.save
            post :unsubscribe, params: { :feeds => ['https://example.com/2'] }
          end

          it 'returns http 200' do
            expect(response).to have_http_status(:ok)
          end

          it 'returns the list of feeds the user is subscribed to' do
            json = JSON.parse(response.body)
            expect(json).to eq(['https://example.com/1'])
          end
        end

        describe 'and the user is subscribed to the specified feeds' do
          let!(:feed) do
            f = Feed.new(url: 'https://example.com/1')
            f.save
            f
          end

          let!(:feed2) do
            f = Feed.new(url: 'https://example.com/2')
            f.save
            f
          end

          before do
            user.feeds << feed
            user.feeds << feed2
            user.save
            post :unsubscribe, params: { :feeds => ['https://example.com/2'] }
          end

          it 'unsubscribes the user from that feed' do
            expect(user.feeds.exists?(feed.id)).to be_truthy
            expect(user.feeds.exists?(feed2.id)).to be_falsy
          end

          it 'returns http 200' do
            expect(response).to have_http_status(:ok)
          end

          it 'returns the list of feeds the user is subscribed to' do
            json = JSON.parse(response.body)
            expect(json).to eq(['https://example.com/1'])
          end
        end
      end
    end
  end

  describe "GET #fetch" do
    it_behaves_like 'an api request' do
      before do
        get :fetch
      end
    end

    describe 'with an application token' do
      before do
        request.headers['X-APP-TOKEN'] = 'GreatSuccess'
      end

      it_behaves_like 'an api requiring a user' do
        before do
          get :fetch
        end
      end

      describe 'with an api token' do
        let!(:user) do
          u = User.new(email: 'user@example.com', password: 'password', password_confirmation: 'password')
          u.save
          u
        end

        let!(:feed) do
          Feed.create(url: 'https://example.com/')
        end

        let!(:old_article) do
          Article.create(title: 'old', updated_at: 15.seconds.ago, published: 20.seconds.ago, url: 'https://example.com/old', feed: feed, content: 'this is an old article')
        end

        let!(:new_article) do
          Article.create(title: 'new', published: 0.seconds.ago, url: 'https://example.com/new', feed: feed, content: 'this is a new article')
        end

        let!(:author) do
          Author.new(name: "foo")
        end

        before do
          user.feeds << feed
          new_article.authors << author
          request.headers['Authorization'] = "Token token=\"#{user.devices.first.api_token}\""
        end

        describe 'with a date parameter' do
          before do
            get :fetch, params: { date: 10.seconds.ago }
          end

          it 'returns http 200' do
            expect(response).to have_http_status(:ok)
          end

          it 'returns feeds and articles published/updated since that date that the user is subscribed to' do
            json = JSON.parse(response.body)
            expected = JSON.parse(JSON.dump({
              "last_updated": feed.updated_at.as_json,
              "feeds": [{
                "title": nil,
                "url": "https://example.com/",
                "summary": nil,
                "image_url": nil,
                "articles": [{
                    "title": "new",
                    "url": "https://example.com/new",
                    "summary": nil,
                    "published": new_article.published.as_json,
                    "updated": nil,
                    "content": "this is a new article",
                    "authors": [{"name": "foo", "email": nil}],
                }]
              }]
            }))
            expect(json).to eq(expected)
          end
        end

        describe 'with a feeds parameter (date parameter for a bunch of feeds)' do
          let!(:feed_2) do
            Feed.create(url: 'https://example.com/feed/2')
          end

          let!(:feed_3) do
            Feed.create(url: 'https://example.com/feed/3')
          end

          let!(:old_article_2) do
            Article.create(title: 'old2', updated_at: 15.seconds.ago, published: 20.seconds.ago, url: 'https://example.com/old_2', feed: feed_2, content: 'this is an old article')
          end

          let!(:old_article_3) do
            Article.create(title: 'old3', updated_at: 8.seconds.ago, published: 20.seconds.ago, url: 'https://example.com/old_3', feed: feed_3, content: 'this is an old article')
          end

          let!(:new_article_2) do
            Article.create(title: 'new2', published: 0.seconds.ago, url: 'https://example.com/new_2', feed: feed_2, content: 'this is a new article')
          end

          let!(:new_article_3) do
            Article.create(title: 'new3', published: 0.seconds.ago, url: 'https://example.com/new_3', feed: feed_3, content: 'this is a new article')
          end

          let!(:extra_articles) do
            create_list(:article, 19, feed: feed_3)
          end

          before do
            user.feeds << [feed_2, feed_3]
            get :fetch, params: {
              feeds: {
                'https://example.com/': 10.seconds.ago,
                'https://example.com/feed/2': 5.seconds.ago,
              }
            }
          end

          it 'returns http 200' do
            expect(response).to have_http_status(:ok)
          end

          it 'returns feeds and articles published/updated since that date for the given feed + the most recent 20 articles for the other feeds that the user is subscribed to' do
            json = JSON.parse(response.body)

            sorted_extra_articles = extra_articles.sort_by {|a| a.published }.reverse
            feed_3_articles = ([new_article_3] + sorted_extra_articles).map do |a|
              {
                title: a.title,
                url: a.url,
                summary: a.summary,
                published: a.published.as_json,
                updated: a.updated.as_json,
                content: a.content,
                authors: a.authors.map {|author| {name: author.name, email: nil }},
              }
            end
            expected = JSON.parse(JSON.dump({
              "feeds": [
                {
                  "last_updated": feed.updated_at.as_json,
                  "title": nil,
                  "url": "https://example.com/",
                  "summary": nil,
                  "image_url": nil,
                  "articles": [{
                      "title": "new",
                      "url": "https://example.com/new",
                      "summary": nil,
                      "published": new_article.published.as_json,
                      "updated": nil,
                      "content": "this is a new article",
                      "authors": [{"name": "foo", "email": nil}],
                  }]
                },
                {
                  "last_updated": feed_2.updated_at.as_json,
                  "title": nil,
                  "url": "https://example.com/feed/2",
                  "summary": nil,
                  "image_url": nil,
                  "articles": [{
                      "title": "new2",
                      "url": "https://example.com/new_2",
                      "summary": nil,
                      "published": new_article_2.published.as_json,
                      "updated": nil,
                      "content": "this is a new article",
                      "authors": [],
                  }]
                },
                {
                  "last_updated": feed_3.updated_at.as_json,
                  "title": nil,
                  "url": "https://example.com/feed/3",
                  "summary": nil,
                  "image_url": nil,
                  "articles": feed_3_articles
                }
              ]
            }))
            expect(json).to eq(expected)
          end
        end

        describe 'without a date parameter' do
          let!(:extra_articles) do
            create_list(:article, 19, feed: feed)
          end

          before do
            get :fetch
          end

          it 'returns http 200' do
            expect(response).to have_http_status(:ok)
          end

          it 'returns all feeds and the 20 most recent articles for those feeds that the user is subscribed to' do
            json = JSON.parse(response.body)
            sorted_extra_articles = extra_articles.sort_by {|a| a.published }.reverse
            articles = ([new_article] + sorted_extra_articles).map do |a|
              {
                title: a.title,
                url: a.url,
                summary: a.summary,
                published: a.published.as_json,
                updated: a.updated.as_json,
                content: a.content,
                authors: a.authors.map {|author| {name: author.name, email: nil }},
              }
            end
            expected = JSON.parse(JSON.dump({
              "last_updated": feed.updated_at.as_json,
              "feeds": [{
                "title": nil,
                "url": "https://example.com/",
                "summary": nil,
                "image_url": nil,
                "articles": articles
              }]
            }))
            expect(json).to eq(expected)
          end
        end
      end
    end
  end
end
