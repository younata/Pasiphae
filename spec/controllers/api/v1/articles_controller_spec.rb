require 'rails_helper'
require 'api_helper'

RSpec.describe Api::V1::ArticlesController, type: :controller do
  describe "POST #update" do
   it_behaves_like 'an api request' do
     before do
       post :update
     end
   end

   describe 'with an application token' do
     before do
       request.headers['X-APP-TOKEN'] = 'GreatSuccess'
     end

     it_behaves_like 'an api requiring a user' do
       before do
         post :update
       end
     end

     describe 'with a user' do
       let!(:user) do
         User.create(email: 'user@example.com', password: 'password', password_confirmation: 'password')
       end

       let!(:feed) do
         Feed.create(url: 'https://example.com/feed')
       end

       let!(:feed_2) do
         Feed.create(url: 'https://example.com/feed2')
       end

       let!(:article_1) do
         Article.create(title: '1', published: 15.seconds.ago, url: 'https://example.com/1', feed: feed, content: '1')
       end

       let!(:article_2) do
         Article.create(title: '2', published: 15.seconds.ago, url: 'https://example.com/2', feed: feed, content: '2')
       end

       let!(:article_3) do
         Article.create(title: '3', published: 15.seconds.ago, url: 'https://example.com/3', feed: feed, content: '3')
       end

       let!(:article_4) do
         Article.create(title: '4', published: 15.seconds.ago, url: 'https://example.com/4', feed: feed, content: '4')
       end

       before do
         user.feeds << [feed, feed_2]
         feed.articles << [article_1, article_2, article_3]
         feed_2.articles << article_4

         user.articles << [article_1, article_2, article_3, article_4]

         user.save

         [[article_1, false], [article_2, true], [article_3, false], [article_4, true]].each do |article, read|
           user_article = article.user_articles.first
           user_article.read = read
           user_article.save
         end

         request.headers['Authorization'] = "Token token=\"#{user.devices.first.api_token}\""
       end

       describe 'marking an article for the user as read' do
         before do
           post :update, params: {
             'articles': {
               'https://example.com/1': true,
               'https://example.com/2': false,
             }
           }
         end

         it 'returns http 200' do
           expect(response).to have_http_status(:ok)
         end

         it 'sets the specified article\'s read status' do
           expect(article_1.user_articles.first.read).to be_truthy
           expect(article_2.user_articles.first.read).to be_falsy
         end

         it 'does not change the unspecified articles' do
           expect(article_3.user_articles.first.read).to be_falsy
           expect(article_4.user_articles.first.read).to be_truthy
         end
       end
     end
   end
  end
end
