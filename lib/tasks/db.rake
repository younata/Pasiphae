namespace :db do
  desc 'prune database of extraneous userarticle associations'
  task :prune => :environment do
    found = []
    UserArticle.find_each do |user_article|
      info = {user: user_article.user_id, article: user_article.article_id}
      if found.include? info
        UserArticle.delete(user_article)
        print '.'
        $stdout.flush
      else
        found << info
      end
    end
  end
end
