require 'rails_helper'
require 'api_helper'

RSpec.describe Api::V1::UserController, type: :controller do
  describe "PUT #create" do
    it_behaves_like 'an api request' do
      before do
        put :create, { :email => 'example@example.com', :password => 'example' }
      end
    end

    describe 'with an application token' do
      before do
        request.headers['X-APP-TOKEN'] = 'GreatSuccess'
      end

      describe 'when a user with that email does not exist' do
        before do
          put :create, { :email => 'example@example.com', :password => 'example' }
        end

        it 'returns http 200' do
          expect(response).to have_http_status(:success)
        end

        it 'creates a new user with that email' do
          expect(User.exists?(email: 'example@example.com')).to be_truthy
        end

        it 'returns an api_token for that user' do
          api_token = JSON.parse(response.body)['api_token']
          device = Device.find_by(api_token: api_token)
          expect(device).to_not be_nil
          expect(device.user.email).to eq('example@example.com')
        end
      end

      describe 'when a user with that email exists' do
        let!(:user) do
          u = User.new(email: 'example@example.com', password: 'password', password_confirmation: 'password')
          u.save
          u
        end

        before do
          put :create, { :email => 'example@example.com', :password => 'other' }
        end

        it 'returns http 400' do
          expect(response).to have_http_status(:bad_request)
        end

        it 'leaks the fact that this user exists' do
          json = JSON.parse(response.body)
          expect(json['error']).to eq("User Exists")
        end
      end
    end
  end

  describe "POST #login" do
    it_behaves_like 'an api request' do
      before do
        post :login
      end
    end

    describe 'with an api token' do
      let!(:user) do
        u = User.new(email: 'example@example.com', password: 'password', password_confirmation: 'password')
        u.save
        u
      end

      before do
        request.headers['X-APP-TOKEN'] = 'GreatSuccess'
      end

      describe 'when a user with that email and password exists' do
        before do
          post :login, { :email => 'example@example.com', :password => 'password' }
        end

        it 'returns http 200' do
          expect(response).to have_http_status(:success)
        end

        it 'creates a second api_token for that user' do
          expect(user.devices.count).to eq(2)
        end

        it 'returns an api_token for that user' do
          api_token = JSON.parse(response.body)['api_token']
          device = Device.find_by(api_token: api_token)
          expect(device).to_not be_nil
          expect(device.user.email).to eq('example@example.com')
        end
      end

      describe 'when a user with that email does not exist' do
        before do
          post :login, { :email => 'user@example.com', :password => 'password' }
        end

        it 'returns http 404' do
          expect(response).to have_http_status(:not_found)
        end

        it 'tells the user that the user or password was not found' do
          json = JSON.parse(response.body)
          expect(json['error']).to eq("Invalid email or password")
        end
      end

      describe 'when a user with that email exists, but has a different password hash' do
        before do
          post :login, { :email => 'example@example.com', :password => 'different_password' }
        end

        it 'returns http 404' do
          expect(response).to have_http_status(:not_found)
        end

        it 'tells the user that the user or password was not found' do
          json = JSON.parse(response.body)
          expect(json['error']).to eq("Invalid email or password")
        end
      end
    end
  end

  describe "PUT #add_device_token" do
    it_behaves_like 'an api request' do
      before do
        put :add_device_token
      end
    end

    describe 'with an application token' do
      before do
        request.headers['X-APP-TOKEN'] = 'GreatSuccess'
      end

      it_behaves_like 'an api requiring a user' do
        before do
          put :add_device_token
        end
      end

      describe 'with a valid user api token' do
        let!(:user) do
          u = User.new(email: 'user@example.com', password: 'password', password_confirmation: 'password')
          u.save
          u
        end

        before do
          request.headers['Authorization'] = "Token token=\"#{user.devices.first.api_token}\""
          put :add_device_token, { :token => 'foofoobarbar' }
        end

        it "returns http success" do
          expect(response).to have_http_status(:success)
        end

        it "assigns the device token to the device used to login" do
          expect(user.devices.first.push_token).to eq('foofoobarbar')
        end
      end
    end
  end

  describe "DELETE #delete" do
    it_behaves_like 'an api request' do
      before do
        delete :delete
      end
    end

    describe 'with an application token' do
      before do
        request.headers['X-APP-TOKEN'] = 'GreatSuccess'
      end

      it_behaves_like 'an api requiring a user' do
        before do
          delete :delete
        end
      end

      describe 'with a valid user api token' do
        let!(:user) do
          u = User.new(email: 'user@example.com', password: 'password', password_confirmation: 'password')
          u.save
          u
        end

        before do
          request.headers['Authorization'] = "Token token=\"#{user.devices.first.api_token}\""
          delete :delete
        end

        it "returns http success" do
          expect(response).to have_http_status(:success)
        end

        it "deletes the user's account" do
          expect(User.all.count).to eq(0)
        end

        it "deletes all devices associated with the user" do
          expect(Device.all.count).to eq(0)
        end
      end
    end
  end
end
