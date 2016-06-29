require 'rails_helper'

RSpec.describe Api::V1::UserController, type: :controller do

  describe "PUT #create" do
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
  end

  describe "GET #delete" do
    it "returns http success" do
      get :delete
      expect(response).to have_http_status(:success)
    end
  end
end
