require 'rails_helper'
require 'api_helper'

RSpec.describe Api::V1::FeedsControllerController, type: :controller do
  describe "POST #subscribe" do
    it_behaves_like 'an api request' do
      before do
        post :subscribe
      end
    end

    describe 'with an application token' do
      before do
        request.headers['APP_TOKEN'] = 'GreatSuccess'
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
          request.headers['Authorization'] = "Token token=\"#{user.devices.first.api_token}\""
        end

        describe 'and none of the feeds specified exist already' do
          before do
            post :subscribe, { :feeds => ['https://example.com/1', 'https://example.com/2'] }
          end

          it 'creates those feeds' do
            expect(Feed.all.count).to eq(2)
            expect(Feed.exists?(url: 'https://example.com/1')).to be_truthy
            expect(Feed.exists?(url: 'https://example.com/2')).to be_truthy
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
            post :subscribe, { :feeds => ['https://example.com/1', 'https://example.com/2'] }
          end

          it 'creates only the unknown feeds' do
            expect(Feed.all.count).to eq(2)
            expect(Feed.exists?(url: 'https://example.com/1')).to be_truthy
            expect(Feed.exists?(url: 'https://example.com/2')).to be_truthy
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
            post :subscribe, { :feeds => ['https://example.com/1', 'https://example.com/2'] }
          end

          it 'creates only the unknown feeds' do
            expect(Feed.all.count).to eq(2)
            expect(Feed.exists?(url: 'https://example.com/1')).to be_truthy
            expect(Feed.exists?(url: 'https://example.com/2')).to be_truthy
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
        request.headers['APP_TOKEN'] = 'GreatSuccess'
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
            post :unsubscribe, { :feeds => ['https://example.com/2'] }
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
            post :unsubscribe, { :feeds => ['https://example.com/2'] }
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
            post :unsubscribe, { :feeds => ['https://example.com/2'] }
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
        request.headers['APP_TOKEN'] = 'GreatSuccess'
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
          f = Feed.new(url: 'https://example.com/')
          f.save
          f
        end

        let!(:old_article) do
          a = Article.new(title: 'old', published: 20.seconds.ago, url: 'https://example.com/old', feed: feed, content: 'this is an old article')
          a.save
          a
        end

        let!(:new_article) do
          a = Article.new(title: 'new', published: 2.seconds.ago, url: 'https://example.com/new', feed: feed, content: 'this is a new article')
          a.save
          a
        end

        let!(:author) do
          a = Author.new(name: "foo")
        end

        before do
          user.feeds << feed
          new_article.authors << author
          request.headers['Authorization'] = "Token token=\"#{user.devices.first.api_token}\""
        end

        describe 'with a date parameter' do
          before do
            get :fetch, { date: 10.seconds.ago.as_json }
          end

          it 'returns http 200' do
            expect(response).to have_http_status(:ok)
          end

          it 'returns feeds and articles published/updated since that date that the user is subscribed to' do
            json = JSON.parse(response.body)
            expected = JSON.parse(JSON.dump([{
              "title": nil,
              "url": "https://example.com/",
              "summary": nil,
              "image_url": nil,
              "articles": [
                {
                  "title": "new",
                  "url": "https://example.com/new",
                  "summary": nil,
                  "published": new_article.published.as_json,
                  "updated": nil,
                  "content": "this is a new article",
                  "authors": [
                    {"name": "foo", "email": nil}
                  ],
                }
              ]
            }]))
            expect(json).to eq(expected)
          end
        end

        describe 'without a date parameter' do
          before do
            get :fetch
          end

          it 'returns http 200' do
            expect(response).to have_http_status(:ok)
          end

          it 'returns all feeds and recent articles the user is subscribed to' do
            json = JSON.parse(response.body)
            expected = JSON.parse(JSON.dump([{
              "title": nil,
              "url": "https://example.com/",
              "summary": nil,
              "image_url": nil,
              "articles": [
                {
                  "title": "old",
                  "url": "https://example.com/old",
                  "summary": nil,
                  "published": old_article.published.as_json,
                  "updated": nil,
                  "content": "this is an old article",
                  "authors": [],
                },
                {
                  "title": "new",
                  "url": "https://example.com/new",
                  "summary": nil,
                  "published": new_article.published.as_json,
                  "updated": nil,
                  "content": "this is a new article",
                  "authors": [
                    {"name": "foo", "email": nil}
                  ],
                }
              ]
            }]))
            expect(json).to eq(expected)
          end
        end
      end
    end
  end
end
