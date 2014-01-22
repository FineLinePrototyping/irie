require 'test_helper'

class Example::Alpha::TestSpecialBarfoosController < ActionDispatch::IntegrationTest

  def setup
    ::DatabaseCleaner.start
    @controller = ::Example::Alpha::SpecialBarfoosController.new
    $test_role = 'admin'
  end

  def teardown
    DatabaseCleaner.clean
  end

  #[:barfoo_url,
  #  :barfoo_path,
  #  :barfoos_url,
  #  :barfoos_path,
  #  :edit_barfoo_url,
  #  :edit_barfoo_path,
  #  :new_barfoo_url,
  #  :new_barfoo_path].each do |m|
  #  test "has method #{m.to_s.inspect} for non-standard model name" do
  #    assert @controller.respond_to? m
  #  end
  #end

  test 'index returns special barfoos with correct fields' do
    expected = []
    10.times do |c|
      expected << Barfoo.create(status: (c % 3), favorite_food: "borscht #{c}", favorite_drink: "vodka #{c}")
    end
    get "/example/alpha/special_barfoos.json"
    assert_equal "{\"check\":\"special_barfoos-index: size=3, ids=borscht 2,borscht 5,borscht 8\"}", response.body
  end

  test 'update allowed for accepted params' do
    b = Barfoo.create(status: 1, favorite_food: "borscht", favorite_drink: "vodka")
    favorite_food = "test"
    put "/example/alpha/special_barfoos/#{b.id}.json", barfoo: {favorite_food: favorite_food}
    
    assert_equal 200, response.status, "unexpected code from update (got #{response.status}): #{response.body}"
    assert_match '{"check":"special_barfoos-update: test"', response.body
    assert Barfoo.where(favorite_food: favorite_food).to_a.size > 0, "should have updated param"
  end

  test 'update responds if doesnt validate' do
    b = Barfoo.create(status: 1, favorite_food: "borscht", favorite_drink: "vodka")
    favorite_food = "." * 51 # max length 15 in model
    put "/example/alpha/special_barfoos/#{b.id}.json", barfoo: {favorite_food: favorite_food}
    assert_equal 422, response.status, "update failed (got #{response.status}): #{response.body}"
    assert_equal '{"errors":{"favorite_food":["is too long (maximum is 15 characters)"]}}', response.body
  end

  test 'update does not accept non-whitelisted params' do
    b = Barfoo.create(status: 1, favorite_food: "borscht", favorite_drink: "vodka")
    favorite_drink = SecureRandom.urlsafe_base64
    begin
      put "/example/alpha/special_barfoos/#{b.id}.json", barfoo: {favorite_drink: favorite_drink}
      fail "should have raised error when attempted to put resource with unpermitted attribute value"
    rescue
      assert_equal [], Barfoo.where(favorite_drink: favorite_drink).to_a, "should not have updated with non-whitelisted param"
    end
  end
end
