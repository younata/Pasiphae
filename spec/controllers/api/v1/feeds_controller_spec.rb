require 'rails_helper'
require 'api_helper'
require 'feed_helper'
include FeedHelper

RSpec.describe Api::V1::FeedsController, type: :controller do
  describe 'GET #check' do
    it_behaves_like 'an api request' do
      before do
        get :check
      end
    end

    describe 'with an application token' do
      before do
        request.headers['X-APP-TOKEN'] = 'GreatSuccess'
      end

      describe 'without a url to check' do
        before do
          allow(FeedHelper).to receive(:is_feed?)
          get :check
        end

        it 'returns http 204' do
          expect(response).to have_http_status(204)
        end

        it 'does no actual checking right now' do
          expect(FeedHelper).to_not have_received(:is_feed?)
        end
      end

      describe 'with a url to check (that is invalid)' do
        before do
          allow(FeedHelper).to receive(:is_feed?).with('https://example.com').and_return(nil)
          allow(FeedHelper).to receive(:is_opml?).with('https://example.com').and_return(nil)
          get :check, params: {url: 'https://example.com'}
        end

        it 'returns http 200' do
          expect(response).to have_http_status(:ok)
        end

        it 'tells the caller that the url is whatever FeedHelper tells it' do
          expect(JSON.parse(response.body, symbolize_names: true)).to eq({'feed': nil, 'opml': nil})
          expect(FeedHelper).to have_received(:is_feed?).with('https://example.com')
        end
      end

      describe 'with a url to check (that is valid)' do
        before do
          allow(FeedHelper).to receive(:is_feed?).with('https://example.com').and_return('https://example.com')
          get :check, params: {url: 'https://example.com'}
        end

        it 'returns http 200' do
          expect(response).to have_http_status(:ok)
        end

        it 'tells the caller that the url is whatever FeedHelper tells it' do
          expect(JSON.parse(response.body, symbolize_names: true)).to eq({'feed': 'https://example.com', 'opml': nil})
          expect(FeedHelper).to have_received(:is_feed?).with('https://example.com')
        end
      end

      describe 'with a url to check (that is an opml)' do
        before do
          allow(FeedHelper).to receive(:is_feed?).with('https://example.com').and_return(nil)
          allow(FeedHelper).to receive(:is_opml?).with('https://example.com').and_return(['https://example.com/1'])
          get :check, params: {url: 'https://example.com'}
        end

        it 'returns http 200' do
          expect(response).to have_http_status(:ok)
        end

        it 'tells the caller that the url is whatever FeedHelper tells it' do
          expect(JSON.parse(response.body, symbolize_names: true)).to eq({'feed': nil, 'opml': ['https://example.com/1']})
          expect(FeedHelper).to have_received(:is_feed?).with('https://example.com')
          expect(FeedHelper).to have_received(:is_opml?).with('https://example.com')
        end
      end
    end
  end

  describe 'POST #subscribe' do
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
          User.create(email: 'user@example.com', password: 'password', password_confirmation: 'password')
        end

        before do
          allow(FeedRefresher).to receive(:perform)
          allow(FeedHelper).to receive(:is_feed?).with('https://example.com/1').and_return(true)
          allow(FeedHelper).to receive(:is_feed?).with('https://example.com/2').and_return(false)
          request.headers['Authorization'] = "Token token=\"#{user.devices.first.api_token}\""
        end

        describe 'trying to subscribe to a not-http/https url' do
          before do
            allow(FeedHelper).to receive(:is_feed?).with('file:///etc/passwd').and_return(false)
            allow(FeedHelper).to receive(:is_feed?).with('mailto://example.com').and_return(false)
            post :subscribe, params: {:feeds => ['file:///etc/passwd', 'mailto://example.com']}
          end

          it 'checks to make sure the feeds are actually feeds' do
            expect(FeedHelper).to have_received(:is_feed?).with('file:///etc/passwd')
            expect(FeedHelper).to have_received(:is_feed?).with('mailto://example.com')
          end

          it 'does not make any new feeds' do
            expect(Feed.all.count).to eq(0)
          end

          it 'returns http 200' do
            expect(response).to have_http_status(:ok)
          end

          it 'returns the list of feeds the user is subscribed to' do
            json = JSON.parse(response.body)
            expect(json).to eq([])
          end
        end

        describe 'and none of the feeds specified exist already' do
          before do
            post :subscribe, params: {:feeds => ['https://example.com/1', 'https://example.com/2']}
          end

          it 'checks to make sure the feeds are actually feeds' do
            expect(FeedHelper).to have_received(:is_feed?).with('https://example.com/1')
            expect(FeedHelper).to have_received(:is_feed?).with('https://example.com/2')
          end

          it 'creates those feeds that are actually feeds' do
            expect(Feed.all.count).to eq(1)
            expect(Feed.exists?(url: 'https://example.com/1')).to be_truthy
            expect(Feed.exists?(url: 'https://example.com/2')).to be_falsy
          end

          it 'enqueues a resque task to update each feed' do
            expect(FeedRefresher).to have_received(:perform).with(Feed.first)
            expect(FeedRefresher).to have_received(:perform).with(Feed.last)
          end

          it 'subscribes the user to those feeds' do
            expect(user.feeds.count).to eq(1)
            feed1 = Feed.find_by(url: 'https://example.com/1')

            expect(user.feeds.exists?(feed1.id)).to be_truthy
          end

          it 'returns http 200' do
            expect(response).to have_http_status(:ok)
          end

          it 'returns the list of feeds the user is subscribed to' do
            json = JSON.parse(response.body)
            expect(json).to eq(['https://example.com/1'])
          end
        end

        describe 'and at least one of the feeds specified exists already' do
          let!(:feed) do
            Feed.create(url: 'https://example.com/1')
          end

          let!(:article) do
            Article.create(title: 'new', published: 0.seconds.ago, url: 'https://example.com/new', feed: feed, content: 'this is a new article')
          end

          before do
            allow(FeedHelper).to receive(:is_feed?).with('https://example.com/1').and_return(true)
            allow(FeedHelper).to receive(:is_feed?).with('https://example.com/2').and_return(true)
            post :subscribe, params: {:feeds => ['https://example.com/1', 'https://example.com/2']}
          end

          it 'checks that the urls are actually feeds' do
            expect(FeedHelper).to have_received(:is_feed?).with('https://example.com/1')
            expect(FeedHelper).to have_received(:is_feed?).with('https://example.com/2')
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

          it 'marks all articles in existing feeds as unread for the user' do
            expect(article.user_articles.count).to eq(1)
            expect(article.user_articles.first.user).to eq(user)
            expect(article.user_articles.first.read).to be_falsy
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
            Feed.create(url: 'https://example.com/1')
          end

          before do
            allow(FeedHelper).to receive(:is_feed?).with('https://example.com/2').and_return(true)
            user.feeds << feed
            user.save
            post :subscribe, params: {:feeds => ['https://example.com/1', 'https://example.com/2']}
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

  describe 'POST #unsubscribe' do
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
          User.create(email: 'user@example.com', password: 'password', password_confirmation: 'password')
        end

        before do
          request.headers['Authorization'] = "Token token=\"#{user.devices.first.api_token}\""
        end

        describe 'and the user is not subscribed to any of the specified feeds' do
          let!(:feed) do
            Feed.create(url: 'https://example.com/1')
          end

          let!(:feed2) do
            Feed.create(url: 'https://example.com/2')
          end

          before do
            user.feeds << feed
            user.save
            post :unsubscribe, params: {:feeds => ['https://example.com/2']}
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
            Feed.create(url: 'https://example.com/1')
          end

          before do
            user.feeds << feed
            user.save
            post :unsubscribe, params: {:feeds => ['https://example.com/2']}
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
            Feed.create(url: 'https://example.com/1')
          end

          let!(:feed2) do
            Feed.create(url: 'https://example.com/2')
          end

          let!(:article) do
            Article.create(title: 'new', published: 0.seconds.ago, url: 'https://example.com/new', feed: feed, content: 'this is a new article')
          end

          let!(:article2) do
            Article.create(title: '2', published: 0.seconds.ago, url: 'https://example.com/new_2', feed: feed2, content: 'this is a new article')
          end

          before do
            user.feeds << feed
            user.feeds << feed2
            user.articles << [article, article2]
            user.save
            post :unsubscribe, params: {:feeds => ['https://example.com/2']}
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

          it 'removes the articles of the deleted feeds from the user' do
            expect(article2.user_articles.count).to eq(0)
          end

          it 'does not remove articles of feeds that are not specified from the user' do
            expect(article.user_articles.count).to eq(1)
            expect(article.user_articles.first.user).to eq(user)
          end
        end
      end
    end
  end

  describe 'get #feeds' do
    it_behaves_like 'an api request' do
      before do
        get :feeds
      end
    end

    describe 'with an application token' do
      before do
        request.headers['X-APP-TOKEN'] = 'GreatSuccess'
      end

      it_behaves_like 'an api requiring a user' do
        before do
          get :feeds
        end
      end

      describe 'with an api token' do
        let!(:user) do
          User.create(email: 'user@example.com', password: 'password', password_confirmation: 'password')
        end

        let!(:feed) do
          Feed.create(url: 'https://example.com/1')
        end

        before do
          user.feeds << feed
          user.save
          request.headers['Authorization'] = "Token token=\"#{user.devices.first.api_token}\""

          get :feeds
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

  describe 'POST #fetch' do
    it_behaves_like 'an api request' do
      before do
        post :fetch
      end
    end

    describe 'with an application token' do
      before do
        request.headers['X-APP-TOKEN'] = 'GreatSuccess'
      end

      it_behaves_like 'an api requiring a user' do
        before do
          post :fetch
        end
      end

      describe 'with an api token' do
        let!(:user) do
          User.create(email: 'user@example.com', password: 'password', password_confirmation: 'password')
        end

        let!(:user_2) do
          User.create(email: 'user2@example.com', password: 'password', password_confirmation: 'password')
        end

        let!(:feed) do
          Feed.create(url: 'https://example.com/')
        end

        let!(:old_article) do
          Article.create(title: 'old', updated: 15.seconds.ago, published: 20.seconds.ago, url: 'https://example.com/old', feed: feed, content: 'this is an old article')
        end

        let!(:old_read_article) do
          Article.create(title: 'old_read', updated: 15.seconds.ago, published: 20.seconds.ago, url: 'https://example.com/old_read', feed: feed, content: 'this is an old article')
        end

        let!(:new_article) do
          Article.create(title: 'new', published: 0.seconds.ago, url: 'https://example.com/new', feed: feed, content: 'this is a new article')
        end

        let!(:author) do
          Author.new(name: 'foo')
        end

        before do
          user.feeds << feed
          user.articles = [old_article, old_read_article, new_article]
          user_2.feeds << feed
          user_2.articles = [old_article, old_read_article, new_article]

          [old_article, new_article].each do |article|
            article.user_articles.each do |user_article|
              user_article.updated_at = 15.seconds.ago
              user_article.save
            end
          end

          old_read_article.user_articles.each do |user_article|
            user_article.read = true
            user_article.updated_at = 0.seconds.ago
            user_article.save
          end

          new_article.authors << author
          request.headers['Authorization'] = "Token token=\"#{user.devices.first.api_token}\""
        end

        describe 'with a feeds parameter (date parameter for a bunch of feeds)' do
          let!(:feed_2) do
            Feed.create(url: 'https://example.com/feed/2')
          end

          let!(:feed_3) do
            Feed.create(url: 'https://example.com/feed/3')
          end

          let!(:old_article_2) do
            article = Article.create(title: 'old2', updated: 15.seconds.ago, published: 20.seconds.ago, url: 'https://example.com/old_2', feed: feed_2, content: 'this is an old article')
            user.articles << article
            user_article = article.user_articles.first
            user_article.updated_at = article.published
            user_article.save
            article
          end

          let!(:old_article_3) do
            article = Article.create(title: 'old3', updated: 8.seconds.ago, published: 20.seconds.ago, url: 'https://example.com/old_3', feed: feed_3, content: 'this is an old article')
            user.articles << article
            user_article = article.user_articles.first
            user_article.updated_at = article.published
            user_article.save
            article
          end

          let!(:new_article_2) do
            article = Article.create(title: 'new2', published: 0.seconds.ago, url: 'https://example.com/new_2', feed: feed_2, content: 'this is a new article')
            user.articles << article
            user_article = article.user_articles.first
            user_article.updated_at = article.published
            user_article.save
            article
          end

          let!(:new_article_3) do
            article = Article.create(title: 'new3', published: 0.seconds.ago, updated: 0.seconds.ago, url: 'https://example.com/new_3', feed: feed_3, content: 'this is a new article')
            user.articles << article
            user_article = article.user_articles.first
            user_article.updated_at = article.published
            user_article.save
            article
          end

          let!(:extra_articles) do
            articles = create_list(:article, 19, feed: feed_3)
            articles.each do |article|
              user.articles << article
              user_article = article.user_articles.first
              user_article.updated_at = article.published
              user_article.save
            end
            articles
          end

          before do
            user.feeds << [feed_2, feed_3]
            post :fetch, params: {
              feeds: JSON.dump({
                'https://example.com/': 10.seconds.ago,
                'https://example.com/feed/2': 5.seconds.ago,
              })
            }
          end

          it 'returns http 200' do
            expect(response).to have_http_status(:ok)
          end

          it 'returns feeds and articles published/updated since that date for the given feed + the most recent 20 articles for the other feeds that the user is subscribed to' do
            json = JSON.parse(response.body)

            sorted_extra_articles = extra_articles.sort_by { |a| a.published }.reverse
            feed_3_articles = ([new_article_3] + sorted_extra_articles).map do |a|
              {
                title: a.title,
                url: a.url,
                summary: a.summary,
                published: a.published.as_json,
                updated: a.updated.as_json,
                content: a.content,
                authors: a.authors.map { |author| {name: author.name, email: nil} },
                read: false,
              }
            end

            expected = JSON.parse(JSON.dump({
              'feeds': [
                {
                  'last_updated': new_article.published.as_json,
                  'title': nil,
                  'url': 'https://example.com/',
                  'summary': nil,
                  'image_url': nil,
                  'articles': [
                    {
                      'title': 'new',
                      'url': 'https://example.com/new',
                      'summary': nil,
                      'published': new_article.published.as_json,
                      'updated': nil,
                      'content': 'this is a new article',
                      'authors': [{'name': 'foo', 'email': nil}],
                      'read': false,
                    },
                    {
                      'title': 'old_read',
                      'url': 'https://example.com/old_read',
                      'summary': nil,
                      'published': old_read_article.published.as_json,
                      'updated': old_read_article.updated.as_json,
                      'content': 'this is an old article',
                      'authors': [],
                      'read': true,
                    }
                  ]
                },
                {
                  'last_updated': new_article_2.published.as_json,
                  'title': nil,
                  'url': 'https://example.com/feed/2',
                  'summary': nil,
                  'image_url': nil,
                  'articles': [{
                    'title': 'new2',
                    'url': 'https://example.com/new_2',
                    'summary': nil,
                    'published': new_article_2.published.as_json,
                    'updated': nil,
                    'content': 'this is a new article',
                    'authors': [],
                    'read': false,
                  }]
                },
                {
                  'last_updated': new_article_3.published.as_json,
                  'title': nil,
                  'url': 'https://example.com/feed/3',
                  'summary': nil,
                  'image_url': nil,
                  'articles': feed_3_articles
                }
              ]
            }))

            expect(json).to eq(expected)
          end
        end

        describe 'without a date parameter' do
          let!(:extra_articles) do
            articles = create_list(:article, 19, feed: feed)
            articles.each do |article|
              user.articles << article
              user_article = article.user_articles.first
              user_article.updated_at = article.published
              user_article.save
            end
            articles
          end

          before do
            post :fetch
          end

          it 'returns http 200' do
            expect(response).to have_http_status(:ok)
          end

          it 'returns all feeds and the 20 most recent articles for those feeds that the user is subscribed to' do
            json = JSON.parse(response.body)
            sorted_extra_articles = extra_articles.sort_by { |a| a.published }.reverse
            articles = ([new_article] + sorted_extra_articles).map do |a|
              {
                title: a.title,
                url: a.url,
                summary: a.summary,
                published: a.published.as_json,
                updated: a.updated.as_json,
                content: a.content,
                authors: a.authors.map { |author| {name: author.name, email: nil} },
                read: a.user_articles.first.read,
              }
            end
            expected = JSON.parse(JSON.dump({
              'last_updated': feed.updated_at.as_json,
              'feeds': [{
                'title': nil,
                'url': 'https://example.com/',
                'last_updated': new_article.published.as_json,
                'summary': nil,
                'image_url': nil,
                'articles': articles
              }]
            }))
            expect(json).to eq(expected)
          end
        end
      end
    end
  end

  describe 'get #articles' do
    it_behaves_like 'an api request' do
      before do
        get :articles
      end
    end

    describe 'with an application token' do
      before do
        request.headers['X-APP-TOKEN'] = 'GreatSuccess'
      end

      describe 'and no feed to check is given' do
        before do
          get :articles
        end

        it 'returns http 204' do
          expect(response).to have_http_status(204)
        end
      end

      describe 'and the feed given is not in the database' do
        before do
          get :articles, params: {feed: 'https://example.com/1'}
        end

        it 'returns http 204' do
          expect(response).to have_http_status(204)
        end
      end

      describe 'and the feed given is in the database' do
        let!(:feed) do
          Feed.create(url: 'https://example.com/1')
        end

        let!(:articles) do
          create_list(:article, 25, feed: feed)
        end

        describe 'with no paging information' do
          before do
            get :articles, params: {feed: 'https://example.com/1'}
          end

          it 'returns http 200' do
            expect(response).to have_http_status(200)
          end

          it 'returns a json document of the most recent 10 articles for this feed' do
            sorted_articles = articles.sort_by { |a| a.published }.reverse
            articles_as_hash = sorted_articles.take(10).map do |a|
              {
                title: a.title,
                url: a.url,
                summary: a.summary,
                published: a.published.as_json,
                updated: a.updated.as_json,
                content: a.content,
                authors: a.authors.map { |author| {name: author.name, email: nil} },
                read: false,
              }
            end

            expected_json = JSON.parse(JSON.dump({'articles': articles_as_hash}))

            expect(JSON.parse(response.body)).to eq(expected_json)
          end
        end

        describe 'with paging information' do
          describe 'asking for the first page' do
            before do
              get :articles, params: {feed: 'https://example.com/1', page: 1}
            end

            it 'returns http 200' do
              expect(response).to have_http_status(200)
            end

            it 'returns a json document of the most recent 10 articles for this feed' do
              sorted_articles = articles.sort_by { |a| a.published }.reverse
              articles_as_hash = sorted_articles.take(10).map do |a|
                {
                  title: a.title,
                  url: a.url,
                  summary: a.summary,
                  published: a.published.as_json,
                  updated: a.updated.as_json,
                  content: a.content,
                  authors: a.authors.map { |author| {name: author.name, email: nil} },
                  read: false,
                }
              end

              expected_json = JSON.parse(JSON.dump({'articles': articles_as_hash}))

              expect(JSON.parse(response.body)).to eq(expected_json)
            end
          end

          describe 'asking for the second page' do
            before do
              get :articles, params: {feed: 'https://example.com/1', page: 2}
            end

            it 'returns http 200' do
              expect(response).to have_http_status(200)
            end

            it 'returns a json document of the most recent 10-20 articles for this feed' do
              sorted_articles = articles.sort_by { |a| a.published }.reverse
              articles_as_hash = sorted_articles[10..19].map do |a|
                {
                  title: a.title,
                  url: a.url,
                  summary: a.summary,
                  published: a.published.as_json,
                  updated: a.updated.as_json,
                  content: a.content,
                  authors: a.authors.map { |author| {name: author.name, email: nil} },
                  read: false,
                }
              end

              expected_json = JSON.parse(JSON.dump({'articles': articles_as_hash}))

              expect(JSON.parse(response.body)).to eq(expected_json)
            end
          end

          describe 'asking for a page with partial amount of articles' do
            before do
              get :articles, params: {feed: 'https://example.com/1', page: 3}
            end

            it 'returns http 200' do
              expect(response).to have_http_status(200)
            end

            it 'returns a json document of the most recent 20+ articles for this feed' do
              sorted_articles = articles.sort_by { |a| a.published }.reverse
              articles_as_hash = sorted_articles[20..25].map do |a|
                {
                  title: a.title,
                  url: a.url,
                  summary: a.summary,
                  published: a.published.as_json,
                  updated: a.updated.as_json,
                  content: a.content,
                  authors: a.authors.map { |author| {name: author.name, email: nil} },
                  read: false,
                }
              end

              expected_json = JSON.parse(JSON.dump({'articles': articles_as_hash}))

              expect(JSON.parse(response.body)).to eq(expected_json)
            end
          end

          describe 'asking for paging information beyond the bounds of the recorded articles' do
            before do
              get :articles, params: {feed: 'https://example.com/1', page: 10}
            end

            it 'returns http 200' do
              expect(response).to have_http_status(200)
            end

            it 'returns a json document of the most recent 10 articles for this feed' do
              expected_json = JSON.parse(JSON.dump({'articles': []}))

              expect(JSON.parse(response.body)).to eq(expected_json)
            end
          end
        end

        describe 'when a user makes this request' do
          let!(:user) do
            User.create(email: 'user@example.com', password: 'password', password_confirmation: 'password')
          end

          before do
            request.headers['Authorization'] = "Token token=\"#{user.devices.first.api_token}\""
          end

          describe 'and the user is not subscribed to this feed' do
            before do
              get :articles, params: {feed: 'https://example.com/1', page: 1}
            end

            it 'returns http 200' do
              expect(response).to have_http_status(200)
            end

            it 'includes read information for the articles' do
              sorted_articles = articles.sort_by { |a| a.published }.reverse
              articles_as_hash = sorted_articles.take(10).map do |a|
                {
                  title: a.title,
                  url: a.url,
                  summary: a.summary,
                  published: a.published.as_json,
                  updated: a.updated.as_json,
                  content: a.content,
                  authors: a.authors.map { |author| {name: author.name, email: nil} },
                  read: false,
                }
              end

              expected_json = JSON.parse(JSON.dump({'articles': articles_as_hash}))

              expect(JSON.parse(response.body)).to eq(expected_json)
            end
          end

          describe 'and the user is subscribed to this feed' do
            before do
              user.feeds << feed
              user.articles = articles

              user.save
            end

            before do
              get :articles, params: {feed: 'https://example.com/1', page: 1}
            end

            it 'returns http 200' do
              expect(response).to have_http_status(200)
            end

            it 'includes read information for the articles' do
              sorted_articles = articles.sort_by { |a| a.published }.reverse
              articles_as_hash = sorted_articles.take(10).map do |a|
                {
                  title: a.title,
                  url: a.url,
                  summary: a.summary,
                  published: a.published.as_json,
                  updated: a.updated.as_json,
                  content: a.content,
                  authors: a.authors.map { |author| {name: author.name, email: nil} },
                  read: false,
                }
              end

              expected_json = JSON.parse(JSON.dump({'articles': articles_as_hash}))

              expect(JSON.parse(response.body)).to eq(expected_json)
            end
          end
        end
      end
    end
  end
end
