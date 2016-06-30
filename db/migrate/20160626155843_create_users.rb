class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :email
      t.string :password_digest

      t.timestamps null: false
    end

    add_index :users, :email, unique: true

    create_table :devices do |t|
      t.string :push_token
      t.string :api_token
      t.belongs_to :user, index: true
    end
  end
end
