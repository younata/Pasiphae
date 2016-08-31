# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160810180359) do

  create_table "articles", force: :cascade do |t|
    t.string   "title"
    t.string   "url"
    t.string   "summary"
    t.datetime "published"
    t.datetime "updated"
    t.string   "content"
    t.integer  "feed_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["feed_id"], name: "index_articles_on_feed_id"
  end

  create_table "articles_authors", id: false, force: :cascade do |t|
    t.integer "article_id"
    t.integer "author_id"
    t.index ["article_id"], name: "index_articles_authors_on_article_id"
    t.index ["author_id"], name: "index_articles_authors_on_author_id"
  end

  create_table "authors", force: :cascade do |t|
    t.string  "name"
    t.string  "email"
    t.integer "article_id"
    t.index ["article_id"], name: "index_authors_on_article_id"
  end

  create_table "devices", force: :cascade do |t|
    t.string  "push_token"
    t.string  "api_token"
    t.integer "user_id"
    t.index ["user_id"], name: "index_devices_on_user_id"
  end

  create_table "feeds", force: :cascade do |t|
    t.string   "title"
    t.string   "url"
    t.string   "summary"
    t.string   "image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "feeds_users", id: false, force: :cascade do |t|
    t.integer "feed_id"
    t.integer "user_id"
    t.index ["feed_id"], name: "index_feeds_users_on_feed_id"
    t.index ["user_id"], name: "index_feeds_users_on_user_id"
  end

  create_table "user_articles", force: :cascade do |t|
    t.integer  "article_id"
    t.integer  "user_id"
    t.boolean  "read",       default: true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["article_id"], name: "index_user_articles_on_article_id"
    t.index ["user_id"], name: "index_user_articles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string   "email"
    t.string   "password_digest"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

end
