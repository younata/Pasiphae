class CreateFeeds < ActiveRecord::Migration
  def change
    create_table :feeds do |t|
      t.string :title
      t.string :url
      t.string :summary
      t.string :image_url

      t.timestamps null: false
    end

    create_table :articles do |t|
      t.string :title
      t.string :url
      t.string :summary
      t.datetime :published
      t.datetime :updated
      t.string :content
      t.belongs_to :feed, index: true
    end

    create_table :authors do |t|
      t.string :name
      t.string :email
      t.belongs_to :article, index: true
    end

    create_table :feeds_users, id: false do |t|
      t.belongs_to :feed, index: true
      t.belongs_to :user, index: true
    end

    create_table :articles_authors, id: false do |t|
      t.belongs_to :article, index: true
      t.belongs_to :author, index: true
    end
  end
end
