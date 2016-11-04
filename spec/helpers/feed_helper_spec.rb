require 'rails_helper'

RSpec.describe FeedHelper, type: :helper do
  describe 'is_feed?' do
    describe 'and the feed url is not an http or https url' do
      it 'does not try to load the url' do
        allow(RestClient).to receive(:get)

        is_feed?('file:///etc/passwd')

        expect(RestClient).to_not have_received(:get)
      end

      it 'returns nil without doing any further analysis' do
        expect(is_feed?('file:///etc/passwd')).to be_nil
      end
    end
    describe 'and the feed is not saved to the database' do
      describe 'and the data at the url does not exist' do
        let!(:failure_response) do
          response_text = 'no'
          instance_double('RestClient::Response', code: 404, body: response_text)
        end

        it 'returns false' do
          allow(RestClient).to receive(:get).with('https://example.com/').and_return(failure_response)
          expect(is_feed?('https://example.com/')).to be_nil
        end
      end

      describe 'and the data at the url is not a feed' do
        let!(:failure_response) do
          response_text = '<html><body>hi</body></html>'
          instance_double('RestClient::Response', code: 200, body: response_text)
        end

        it 'returns false' do
          allow(RestClient).to receive(:get).with('https://example.com/').and_return(failure_response)
          expect(is_feed?('https://example.com/')).to be_nil
        end
      end

      describe 'and the data at the url is a feed' do
        let!(:successful_response) do
          response_text = IO.read(Rails.root.join('spec', 'fixtures', 'rss2.0.xml'))
          instance_double('RestClient::Response', code: 200, body: response_text)
        end

        it 'returns true' do
          allow(RestClient).to receive(:get).with('https://example.com/').and_return(successful_response)
          expect(is_feed?('https://example.com/')).to eq('https://example.com/')
        end
      end
    end

    describe 'and the feed exists in the database' do
      let!(:feed) do
        Feed.create(title: nil, url: 'https://example.com', summary: nil, image_url: nil)
      end

      it 'returns true' do
        expect(is_feed?(feed.url + '/')).to eq('https://example.com')
      end
    end
  end

  describe 'is_opml?' do
    describe 'and the url is not an http or https url' do
      it 'does not try to load the url' do
        allow(RestClient).to receive(:get)

        is_opml?('file:///etc/passwd')

        expect(RestClient).to_not have_received(:get)
      end

      it 'returns nil without doing any further analysis' do
        expect(is_opml?('file:///etc/passwd')).to be_nil
      end
    end

    describe 'and the data at the url is an opml file' do
      let!(:success) do
        response_text = IO.read(Rails.root.join('spec', 'fixtures', 'test.opml'))
        instance_double('RestClient::Response', code: 200, body: response_text)
      end

      it 'returns a list of feeds' do
        allow(RestClient).to receive(:get).with('https://example.com/').and_return(success)
        expect(is_opml?('https://example.com/')).to eq(['http://example.com/feedWithTag', 'http://example.com/previouslyImportedFeed', 'http://example.com/feedWithTitle'])
      end
    end

    describe 'and the data at the url is not an opml file' do
      let!(:failure_response) do
        response_text = 'no'
        instance_double('RestClient::Response', code: 200, body: response_text)
      end

      it 'returns a list of feeds' do
        allow(RestClient).to receive(:get).with('https://example.com/').and_return(failure_response)
        expect(is_opml?('https://example.com/')).to be_nil
      end
    end

    describe 'and there is no data at the url' do
      let!(:failure_response) do
        response_text = 'no'
        instance_double('RestClient::Response', code: 404, body: response_text)
      end

      it 'returns nil' do
        allow(RestClient).to receive(:get).with('https://example.com/').and_return(failure_response)
        expect(is_opml?('https://example.com/')).to be_nil
      end
    end
  end

  describe 'refresh feed' do
    let!(:feed) do
      Feed.create(title: nil, url: "https://example.com", summary: nil, image_url: nil)
    end

    context 'for an rss 2.0 feed' do
      let!(:article) do
        Article.create(title: 'Issue #17: Security', summary: 'this will be replaced', published: DateTime.parse('Fri, 10 Oct 2014 13:00:00 +0000'), url: 'http://www.objc.io/issue-17', feed: feed)
      end

      let!(:successful_response) do
        response_text = IO.read(Rails.root.join("spec", "fixtures", "rss2.0.xml"))
        instance_double('RestClient::Response', code: 200, body: response_text)
      end

      before do
        allow(RestClient).to receive(:get).with(feed.url).and_return(successful_response)
        update_rss_feed(feed)
      end

      it 'fetches the feed at the given url' do
        expect(RestClient).to have_received(:get).with(feed.url)
      end

      it 'updates the feed information' do
        expect(feed.title).to eq('objc.io')
        expect(feed.summary).to eq('A periodical about best practices and advanced techniques for iOS and OS X development.')
        expect(feed.image_url).to eq('http://example.org/icon.png')
      end

      it 'inserts articles into the database for every new article it finds, without duplicating existing articles' do
        expect(feed.articles.count).to eq(11)
        expect(Article.all.count).to eq(11)
      end

      it 'updates existing articles with new information about them' do
        updated_article = Article.find(article.id)
        expect(updated_article.summary).to eq("<p>This issue is about security. It&rsquo;s a relatively small issue, since September was a busy month for us and our contributors. Nevertheless, we have some great articles on code signing, receipt validation, and why security still matters today.   </p>\n")
      end
    end

    context 'for a feed with articles that have relative urls' do
      let!(:successful_response) do
        response_text = IO.read(Rails.root.join("spec", "fixtures", "carthage_releases.xml"))
        instance_double('RestClient::Response', code: 200, body: response_text)
      end

      before do
        allow(RestClient).to receive(:get).with(feed.url).and_return(successful_response)
        update_rss_feed(feed)
      end

      it 'fetches the feed at the given url' do
        expect(RestClient).to have_received(:get).with(feed.url)
      end

      it 'inserts the article, using the feed host as the base url' do
        article = Article.first
        expect(article.url).to eq('https://example.com/Carthage/Carthage/releases/tag/0.17.2')
      end
    end

    context 'for an atom feed' do
      let!(:article) do
        a = Article.new(title: 'Atom draft-07 snapshot', content: 'this will be replaced', published: DateTime.parse('2003-12-13T08:29:29-04:00'), url: 'http://example.org/2005/04/02/atom', feed: feed)
        a.save
        a
      end

      let!(:successful_response) do
        response_text = IO.read(Rails.root.join("spec", "fixtures", "atom.1.0.xml"))
        instance_double('RestClient::Response', code: 200, body: response_text)
      end

      before do
        allow(RestClient).to receive(:get).with(feed.url).and_return(successful_response)
        update_rss_feed(feed)
      end

      it 'fetches the feed at the given url' do
        expect(RestClient).to have_received(:get).with(feed.url)
      end

      it 'updates the feed information' do
        expect(feed.title).to eq('dive into mark')
        expect(feed.summary).to eq('A <em>lot</em> of effort went into making this effortless')
        expect(feed.image_url).to eq('http://example.org/icon.gif')
      end

      it 'inserts articles into the database for every new article it finds, without duplicating existing articles' do
        expect(Article.all.count).to eq(2)
        expect(feed.articles.count).to eq(2)
      end

      it 'updates existing articles with new information about them' do
        updated_article = Article.find(article.id)
        expect(updated_article.content).to eq("[Update: The Atom draft is finished.]")
        expect(updated_article.updated).to eq(DateTime.parse('2005-07-31T12:29:29Z'))

        expect(updated_article.authors.count).to eq(1)
        expect(updated_article.authors.first.name).to eq('Mark Pilgrim')
      end
    end
  end
end
