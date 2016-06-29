require 'rails_helper'

RSpec.describe Device, type: :model do
  let!(:user) do
    u = User.new(email: 'user@example.com', password: 'password', password_confirmation: 'password')
    u.save
    u
  end
  let!(:device) do
    d = Device.new(push_token: nil, user: user)
    d.save
    d
  end

  it 'requires a user' do
    other_device = Device.new(push_token: nil, api_token: nil, user: nil)
    expect(other_device.valid?).to be_falsy
  end

  describe 'api_token' do
    it 'generates an api_token' do
      expect(device.api_token).to_not be_nil
    end
  end

  it 'does not require a push_token' do
    device.push_token = nil
    expect(device.valid?).to be_truthy
  end
end
