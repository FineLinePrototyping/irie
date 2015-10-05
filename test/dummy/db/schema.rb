ActiveRecord::Schema.define do
  create_table :foos do |t|
    t.string :code
    t.integer :bar_id
    t.integer :barfoo_id
  end

  create_table :bars do |t|
    t.integer :foobar_id
    t.string :code
    t.string :open_hours
  end

  create_table :foobars do |t|
    t.integer :bar_id
    t.integer :foo_id
    t.integer :barfoo_id
    t.integer :foobar_id
    t.datetime :foo_date
    t.datetime :bar_date
  end

  create_table :barfoos do |t|
    t.string :status
    t.string :favorite_drink
    t.string :favorite_food
  end

  create_table :users do |t|
    t.string :role
  end

  create_table :posts do |t|
    t.string :name
    t.string :title
    t.text :content

    t.timestamps null: true
  end

  create_table :my_posts do |t|
    t.string :name
    t.string :title
    t.text :content

    t.timestamps null: true
  end
end
