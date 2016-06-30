require 'rails_helper'

RSpec.describe Feed, type: :model do
  let!(:feed) do
    f = Feed.new(title: nil, url: "https://example.com", summary: nil, image_url: nil)
    f.save
    f
  end

  it 'is currently valid' do
    expect(feed.valid?).to be_truthy
  end

  describe 'url' do
    it 'requires a an actual url' do
      feed.url = 'hello'
      expect(feed.valid?).to be_falsy
    end

    it 'does not allow duplicate urls' do
      other_feed = feed.dup
      expect(other_feed.valid?).to be_falsy

      other_feed.url = feed.url.upcase
      expect(other_feed.valid?).to be_falsy

      other_feed.url = 'https://google.com'
      expect(other_feed.valid?).to be_truthy
    end
  end
end
