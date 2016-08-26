require 'rails_helper'

RSpec.describe StatusBoardControllerController, type: :controller do
  let!(:feed_1) do
    Feed.create(url: 'https://example.com/feed/1')
  end

  let!(:feed_2) do
    Feed.create(url: 'https://example.com/feed/2')
  end

  let!(:other_feeds) do
    (1..10).each do |i|
      Feed.create(url: "https://example.com/feed/#{i+10}")
    end
  end

  let!(:feed_1_articles) do
    create_list(:article, 14, feed: feed_1)
  end

  let!(:feed_2_articles) do
    create_list(:article, 16, feed: feed_2)
  end

  let!(:user_1) do
    user = User.create(email: 'user1@example.com', password: 'password', password_confirmation: 'password')
    user.feeds << feed_1
    user.feeds << feed_2
    user
  end

  let!(:user_2) do
    user = User.create(email: 'user2@example.com', password: 'password', password_confirmation: 'password')
    user.feeds << feed_1
    user
  end

  describe "GET #current" do
    describe 'without authorization' do
      it "returns unauthorized" do
        get :current
        expect(response).to have_http_status(401)
        expect(response.body).to eq("HTTP Basic: Access denied.\n")
      end
    end

    describe 'with authorization' do
      before do
        user = 'test_admin'
        pw = 'test_pw'
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(user,pw)
      end

      it "returns http success" do
        get :current
        expect(response).to have_http_status(:success)

        csv = CSV.parse(response.body)
        expected = [
          ['75%', '25%'],
          ['Users', '2'],
          ['Feeds', '12'],
          ['Average Feeds/User', '1.5'],
          ['Highest Feeds/User', '2'],
          ['Articles', '30'],
          ['Authors', '0'],
        ]
        expect(csv).to eq(expected)
      end
    end
  end

  describe "GET #popular" do
    describe 'without authorization' do
      it "returns unauthorized" do
        get :popular
        expect(response).to have_http_status(401)
        expect(response.body).to eq("HTTP Basic: Access denied.\n")
      end
    end

    describe 'with authorization' do
      before do
        user = 'test_admin'
        pw = 'test_pw'
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(user,pw)
      end

      it "returns http success" do
        get :popular
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET #usage" do
    describe 'without authorization' do
      it "returns unauthorized" do
        get :usage
        expect(response).to have_http_status(401)
        expect(response.body).to eq("HTTP Basic: Access denied.\n")
      end
    end

    describe 'with authorization' do
      before do
        user = 'test_admin'
        pw = 'test_pw'
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(user,pw)
      end

      it "returns http success" do
        get :usage
        expect(response).to have_http_status(:success)
      end
    end
  end
end
