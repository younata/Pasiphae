FactoryGirl.define do
  sequence :url do |n|
    "https://example.com/#{n}"
  end
  factory :article do
    title 'article'
    published { 1.seconds.ago }
    updated { 1.seconds.ago }
    url
    content 'content'
  end
end
