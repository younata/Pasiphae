namespace :db do
  desc 'prune database of extraneous userarticle associations'
  task :prune => :environment do
    found = []
    to_delete = []
    count = 0

    DELETE_FLUSH_COUNT = 500

    UserArticle.find_each do |user_article|
      info = {user: user_article.user_id, article: user_article.article_id}
      if found.include? info
        to_delete << user_article
        print '.'
        $stdout.flush
      else
        found << info
      end
      count += 1

      if to_delete.count >= DELETE_FLUSH_COUNT
        UserArticle.delete(to_delete)
        to_delete = []
        puts "\n#{UserArticle.count} - #{count}"
      end
    end
    UserArticle.delete(to_delete)
    to_delete = []
    puts "\n#{UserArticle.count} - #{count}"
  end
end
