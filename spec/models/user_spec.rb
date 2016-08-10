require 'rails_helper'

RSpec.describe User, type: :model do
  let!(:user) do
    User.create(email: 'user@example.com', password: 'password', password_confirmation: 'password')
  end

  it 'creates a device/api token for this user' do
    expect(user.devices.length).to eq(1)
  end

  describe 'email' do
    it 'requires email' do
      expect(user.valid?).to be_truthy
    end

    it 'does not allow nil emails' do
      user.email = nil
      expect(user.valid?).to be_falsy
    end

    it 'does not allow empty emails' do
      user.email = ''
      expect(user.valid?).to be_falsy
    end

    it 'does not allow duplicate usernames (case insensitive)' do
      other_user = user.dup
      expect(other_user.valid?).to be_falsy

      other_user.email = user.email.upcase
      expect(other_user.valid?).to be_falsy

      other_user.email = 'some_other_string'
      expect(other_user.valid?).to be_truthy
    end
  end

  describe 'password' do
    it 'does not allow nil passwords' do
      user.password = nil
      expect(user.valid?).to be_falsy
    end

    it 'does not allow empty passwords' do
      user.password = ''
      user.password_confirmation = ''
      expect(user.valid?).to be_falsy
    end
  end
end
