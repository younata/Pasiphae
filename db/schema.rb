# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20160730032252) do

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
  end

  add_index "articles", ["feed_id"], name: "index_articles_on_feed_id"

  create_table "articles_authors", id: false, force: :cascade do |t|
    t.integer "article_id"
    t.integer "author_id"
  end

  add_index "articles_authors", ["article_id"], name: "index_articles_authors_on_article_id"
  add_index "articles_authors", ["author_id"], name: "index_articles_authors_on_author_id"

  create_table "authors", force: :cascade do |t|
    t.string  "name"
    t.string  "email"
    t.integer "article_id"
  end

  add_index "authors", ["article_id"], name: "index_authors_on_article_id"

  create_table "devices", force: :cascade do |t|
    t.string  "push_token"
    t.string  "api_token"
    t.integer "user_id"
  end

  add_index "devices", ["user_id"], name: "index_devices_on_user_id"

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
  end

  add_index "feeds_users", ["feed_id"], name: "index_feeds_users_on_feed_id"
  add_index "feeds_users", ["user_id"], name: "index_feeds_users_on_user_id"

  create_table "users", force: :cascade do |t|
    t.string   "email"
    t.string   "password_digest"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true

end
