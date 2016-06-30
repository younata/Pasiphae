require 'rails_helper'

RSpec.describe Article, type: :model do
  let!(:feed) do
    f = Feed.new(title: "title", url: "https://example.com", summary: nil, image_url: nil)
    f.save
    f
  end

  let!(:article) do
    a = Article.new(title: "title", url: "https://example.com/url", summary: "", published: DateTime.now, updated: nil, content: "hello world", feed: feed)
    a.save
    a
  end

  it 'is currently valid' do
    expect(article.valid?).to be_truthy
  end

  it 'requires a feed' do
    article.feed = nil
    expect(article.valid?).to be_falsy
  end

  it 'requires a published date' do
    article.published = nil
    expect(article.valid?).to be_falsy
  end

  it 'requires a title' do
    article.title = nil
    expect(article.valid?).to be_falsy
  end

  describe 'url' do
    it 'requires a valid url' do
      article.url = "hello"
      expect(article.valid?).to be_falsy
    end

    it 'does not allow duplicate urls' do
      other = article.dup
      expect(other.valid?).to be_falsy

      other.url = article.url.upcase
      expect(other.valid?).to be_falsy
      
      other.url = 'https://google.com'
      expect(other.valid?).to be_truthy
    end
  end
end
