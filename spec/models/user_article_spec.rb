require 'rails_helper'

RSpec.describe UserArticle, type: :model do
  let!(:article) do
    feed = Feed.create(title: "title", url: "https://example.com", summary: nil, image_url: nil)
    Article.create(title: "title", url: "https://example.com/url", summary: "", published: DateTime.now, updated: nil, content: "hello world", feed: feed)
  end

  let!(:user) do
    User.create(email: 'user@example.com', password: 'password', password_confirmation: 'password')
  end

  let!(:subject) do
    user.articles << article
    user.save
    user.user_articles.first
  end

  it 'is an actual thing' do
    expect(subject).to_not be_nil
  end

  it 'allows read to be either false or true' do
    expect(subject.read).to be_falsy
    subject.read = true
    expect(subject.valid?).to be_truthy
    subject.read = false
    expect(subject.valid?).to be_truthy
  end
end
