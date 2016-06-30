require 'rails_helper'

RSpec.shared_examples "an api request" do
  describe 'without an application token' do
    it 'rejects the request with http 401' do
      expect(response).to have_http_status(401)
    end

    it 'tells the user why' do
      expect(response.body).to eq("HTTP Token: Access denied.\n")
    end
  end
end

RSpec.shared_examples "an api requiring a user" do
  describe 'without a user token' do
    it 'rejects the request with http 401' do
      expect(response).to have_http_status(401)
    end

    it 'tells the user why' do
      expect(response.body).to eq("HTTP Token: Access denied.\n")
    end
  end
end
