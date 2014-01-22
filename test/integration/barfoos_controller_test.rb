require 'test_helper'

class TestBarfoosController < ActionDispatch::IntegrationTest

  def setup
    DatabaseCleaner.start
    @controller = BarfoosController.new
    $resource_has_errors = false
    $test_role = 'admin'
  end

  def teardown
    DatabaseCleaner.clean
  end

  test 'index does not fail authorization if not enabled' do
    barfoo = Barfoo.create(status: 1, favorite_food: "borscht", favorite_drink: "vodka", foobars: [Foobar.create])
    $test_role = 'guest'
    get "/barfoos.json"
    assert_equal "{\"check\":\"barfoos-index: size=0, statuses=\"}", response.body
  end

  test 'index returns barfoos via index query' do
    10.times do |c|
      Barfoo.create(status: (c % 3), favorite_food: "borscht #{c}", favorite_drink: "vodka #{c}", foobars: [Foobar.create])
    end
    get "/barfoos.json"
    # note: ids, created_at, updated_at and order of keys are ignored- see https://github.com/collectiveidea/json_spec
    assert_equal "{\"check\":\"barfoos-index: size=3, statuses=borscht 2,borscht 5,borscht 8\"}", response.body
  end

  test 'index returns autorendered count' do
    10.times do |c|
      Barfoo.create(status: (c % 3), favorite_food: "borscht #{c}", favorite_drink: "vodka #{c}", foobars: [Foobar.create])
    end
    get "/barfoos.json?count="
    # note: ids, created_at, updated_at and order of keys are ignored- see https://github.com/collectiveidea/json_spec
    assert_equal "{\"count\":3}", response.body
  end

  test 'index can page' do
    60.times do |c|
      Barfoo.create(status: (c % 3), favorite_food: "borscht #{c}", favorite_drink: "vodka #{c}", foobars: [Foobar.create])
    end
    get "/barfoos.json?page=1"
    # note: ids, created_at, updated_at and order of keys are ignored- see https://github.com/collectiveidea/json_spec
    assert_equal "{\"check\":\"barfoos-index: size=15, statuses=borscht 2,borscht 5,borscht 8,borscht 11,borscht 14,borscht 17,borscht 20,borscht 23,borscht 26,borscht 29,borscht 32,borscht 35,borscht 38,borscht 41,borscht 44\"}", response.body
    get "/barfoos.json?page=2"
    # note: ids, created_at, updated_at and order of keys are ignored- see https://github.com/collectiveidea/json_spec
    assert_equal "{\"check\":\"barfoos-index: size=5, statuses=borscht 47,borscht 50,borscht 53,borscht 56,borscht 59\"}", response.body
  end

  test 'index returns autorendered page count' do
    10.times do |c|
      Barfoo.create(status: (c % 3), favorite_food: "borscht #{c}", favorite_drink: "vodka #{c}", foobars: [Foobar.create])
    end
    get "/barfoos.json?page_count="
    # note: ids, created_at, updated_at and order of keys are ignored- see https://github.com/collectiveidea/json_spec
    assert_equal "{\"page_count\":1}", response.body
  end

  #TODO: either something wrong with this test, or edit does not autorender validation errors
  #test 'edit validation errors autorendering works' do
  #  barfoo = Barfoo.create(status: 1, favorite_food: "borscht", favorite_drink: "vodka", foobars: [Foobar.create])
  #  $resource_has_errors = true
  #  get "/barfoos/#{barfoo.id}/edit.json"
  #  assert_equal "{\"errors\":{\"base\":[\"sample edit errors\"]}}", response.body
  #end

  # note: the following validation checks are testing non-Irie functionality, just to confirm

  test 'create validation errors autorendering works' do
    post "/barfoos.json", barfoo: {favorite_food: "x" * 20}
    assert_equal "{\"errors\":{\"favorite_food\":[\"is too long (maximum is 15 characters)\"]}}", response.body
  end

  test 'update validation errors autorendering works' do
    barfoo = Barfoo.create(status: 1, favorite_food: "borscht", favorite_drink: "vodka", foobars: [Foobar.create])
    put "/barfoos/#{barfoo.id}.json", barfoo: {id: barfoo.id, favorite_food: "x" * 20}
    assert_equal "{\"errors\":{\"favorite_food\":[\"is too long (maximum is 15 characters)\"]}}", response.body
  end

  test 'destroy validation errors autorendering works' do
    barfoo = Barfoo.create(status: 1, favorite_food: "borscht", favorite_drink: "vodka", foobars: [Foobar.create])
    $resource_has_errors = true
    delete "/barfoos/#{barfoo.id}.json"
    assert_equal "{\"errors\":{\"base\":[\"sample destroy errors\"]}}", response.body
  end
end
