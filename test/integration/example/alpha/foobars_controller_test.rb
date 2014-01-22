require 'test_helper'

class Example::Alpha::TestFoobarsController < ActionDispatch::IntegrationTest
  
  def setup
    ::DatabaseCleaner.start
    @controller = Example::Alpha::FoobarsController.new
    $test_role = 'admin'

    10.times do |c|
      bar = Bar.create(code: "abc#{c}", open_hours: c)
      foo = Foo.create(code: "123#{c}", bar: bar)
      Foobar.create(foo: foo)
    end
  end

  def teardown
    DatabaseCleaner.clean
  end

  test 'index returns foobars in default order with default filter' do
    expected = Foobar.all.to_a.reject!{|i|i.foo_id == 3} # default filter

    get "/example/alpha/awesome_routing_scope/foobars.json"
    assert_equal expected.reverse, assigns(:foobars).to_a
    # note: ids, created_at, updated_at and order of keys are ignored- see https://github.com/collectiveidea/json_spec
    assert_equal "{\"check\":\"foobars-index: size=#{expected.length}, ids=#{expected.reverse.collect{|f|f.id}.join(',')}\"}", response.body
  end

  test 'index returns foobars via through filter' do
    if Rails::VERSION::MAJOR < 4
      expected_foobar = Foobar.joins(foo: :bar).where(Bar.arel_table[:open_hours].eq(Bar.last.open_hours)).to_a.first
    else
      expected_foobar = Foobar.all.joins(foo: :bar).where(Bar.arel_table[:open_hours].eq(Bar.last.open_hours)).to_a.first
    end

    get "/example/alpha/awesome_routing_scope/foobars.json?open_hours=#{Foobar.last.foo.bar.open_hours}"
    assert_equal 1, assigns(:foobars).length
    assert_equal "{\"check\":\"foobars-index: size=1, ids=#{expected_foobar.id}\"}", response.body
  end

  test 'index allows requested ascending order with default filter' do
    expected = Foobar.all.to_a.reject!{|i|i.foo_id == 3} # default filter
    queries = QueryCollector.collect_all do
      get "/example/alpha/awesome_routing_scope/foobars.json?order=foo_id,+bar_code,-renamed_foo_id"
    end
    assert_equal expected, assigns(:foobars).to_a
    # note: ids, created_at, updated_at and order of keys are ignored- see https://github.com/collectiveidea/json_spec
    first_id = expected.last.id-(expected.length - 1)
    last_id = expected.last.id
    assert_equal "{\"check\":\"foobars-index: size=#{expected.length}, ids=#{expected.collect{|f|f.id}.join(',')}\"}", response.body
    # experimental at the moment. eventually want to try to cleanly ensure includes are being used
    query_count = queries.select{|r|r.last.try(:[],:name).try(:end_with?," Load")}.count
    assert_equal 2, query_count, "Expected /example/alpha/awesome_routing_scope/foobars.json?order=foo_id,+bar_code,-renamed_foo_id to have 2 load queries, but had #{query_count} load queries: #{queries.inspect}"
  end

  test 'index returns foobars with simple filter' do
    expected = [Foobar.first]
    
    get "/example/alpha/awesome_routing_scope/foobars.json?foo_id=#{expected.first.foo.id}"
    assert_equal expected, assigns(:foobars).to_a
  end

  test 'index returns foobars with defined param filter' do
    expected = [Foobar.first]

    get "/example/alpha/awesome_routing_scope/foobars.json?renamed_foo_id=#{expected.first.foo.id}"
    assert_equal expected, assigns(:foobars).to_a
  end

  test 'index returns foobars with a query' do
    expected = [Foobar.first]
    #fail Foobar.all.collect {|f| "foobar#{f.id}.foo#{f.foo.id}"}.join(', ')

    get "/example/alpha/awesome_routing_scope/foobars.json?a_query=#{expected.first.foo.id}"
    assert_equal expected, assigns(:foobars).to_a
  end

  test 'show assigns foobar' do
    foobar = Foobar.first

    get "/example/alpha/awesome_routing_scope/foobars/#{foobar.id}.json"
    assert assigns(:foobar).is_a?(Foobar)
    assert_equal response.status, 200, "show returned unexpected response code (got #{response.status}): #{response.body}"
    # note: ids, created_at, updated_at and order of keys are ignored- see https://github.com/collectiveidea/json_spec
    assert_equal "{\"check\":\"foobars-show: #{foobar.id}\"}", response.body
  end

  test 'show fails for bad id' do
    begin
      get "/example/alpha/awesome_routing_scope/foobars/9999999"
      fail('should have raised error')
    rescue => e
    end
  end

  test 'new assigns foobar' do
    # note: the foobar get param is a problem with allowing params to be used to
    # initialize a new object while using require in the method for S.P.
    # rather than an inherent problem with using IR or Irie.
    get "/example/alpha/awesome_routing_scope/foobars/new.json"
    #assert assigns(:foobar).is_a?(Foobar)
    assert_equal response.status, 200, "new returned unexpected response code (got #{response.status}): #{response.body}"
    # note: ids, created_at, updated_at and order of keys are ignored- see https://github.com/collectiveidea/json_spec
    assert_equal "{\"check\":\"foobars-new: \"}", response.body
  end

  test 'new fails when cancan disallows user' do
    $test_role = 'nobody'

    begin
      get "/example/alpha/awesome_routing_scope/foobars/new.json"
      fail "cancan should not allow get" if response.status < 400
    rescue
    end
  end

  test 'edit assigns foobar' do
    foobar = Foobar.last
    get "/example/alpha/awesome_routing_scope/foobars/#{foobar.id}/edit.json"
    assert assigns(:foobar).is_a?(Foobar)
    assert_equal foobar.foo_id, assigns(:foobar).foo_id
  end

  test 'edit fails for bad id' do
    begin
      get "/example/alpha/awesome_routing_scope/foobars/9999999.json"
      fail "should have raised error"
    rescue
    end
  end

  test 'edit fails when cancan disallows user' do
    $test_role = 'nobody'

    begin
      get "/example/alpha/awesome_routing_scope/foobars/#{Foobar.last.id}.json"
      fail "cancan should not allow get" if response.status < 400
    rescue
    end
  end
  
  test 'create allowed for accepted params' do
  #autolog :methods, format: :taw do
    Foobar.delete_all
    before_count = Foobar.count
    code = "new#{rand(99999)}"
    queries = QueryCollector.collect_all do
      post "/example/alpha/awesome_routing_scope/foobars.json", foobar: {foo_attributes: {code: code}}    
      assert_equal 200, response.status, "Bad response code (got #{response.status}): #{response.body}"
      s = response.body
    end
    
    assert_equal before_count + 1, Foobar.count, "Didn't create Foobar"
    last_foobar = Foobar.last
    assert_equal code, last_foobar.foo.code

    # Starting to do a few RFC 2616 (http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10.2.1)
    # conformance checks, back when was trying to ensure path and url method etc. setup.
    #TODO: Once stable and have time, clean-up/remove tests for functionality that isn't a part of Irie.
    assert_equal "http://www.example.com/example/alpha/awesome_routing_scope/foobars/#{last_foobar.id}", response.headers['Location'], "didn't include expected location header. was #{response.headers['Location']}"
    assert_equal "application/json; charset=utf-8", response.headers['Content-Type'], "didn't include expected content-type. was #{response.headers['Content-Type']}"
    assert_equal "{\"check\":\"foobars-create: #{last_foobar.id}, foo: #{last_foobar.foo.id}\"}", response.body
    # experimental at the moment. eventually want to try to cleanly ensure includes are being used
    query_count = queries.select{|r|r.last.try(:[],:name).try(:end_with?," Load")}.count
    assert_equal 2, query_count, "Expected /example/alpha/awesome_routing_scope/foobars.json to have 2 load queries, but had #{query_count} load queries: #{queries.inspect}"    
  #end
  end

  test 'create does not accept non-whitelisted params' do
    before_count = Foobar.count
    begin
      code = "new#{rand(99999)}"
      bar = Bar.create
      post "/example/alpha/awesome_routing_scope/foobars.json", foobar: {bar_id: bar.id, foo_attributes: {code: code}}
      fail 'Expected ActionController::UnpermittedParameters to be raised for non-whitelisted param'
    rescue ActionController::UnpermittedParameters
      assert_equal before_count, Foobar.count
    end
  end

  test 'create does not create when cancan disallows user' do
    $test_role = 'nobody'

    before_count = Foobar.count
    begin
      code = "new#{rand(99999)}"
      bar = Bar.create
      post "/example/alpha/awesome_routing_scope/foobars.json", foobar: {bar_id: bar.id, foo_attributes: {code: code}}
      fail 'Expected error to be raised'
    rescue
      assert_equal before_count, Foobar.count
    end
  end

  test 'update allowed for accepted params and honors includes request' do
    foobar = Foobar.create(foo_id: Foo.last.id)
    foo_id = Foo.first.id
    patch "/example/alpha/awesome_routing_scope/foobars/#{foobar.id}.json", foobar: {foo_id: foo_id}
    # this controller is set to return entity on update, so will return 200 instead of 204
    assert_equal 200, response.status, "update returned unexpected response code (got #{response.status}): #{response.body}"
    last_foobar = Foobar.last
    assert_match "{\"check\":\"foobars-update: #{Foobar.last.id}, foo: #{last_foobar.foo.id}, bar: #{last_foobar.foo.bar.id}\"}", response.body
    assert_equal foo_id, Foobar.find(foobar.id).foo_id, "should have updated param"
  end

  test 'update does not accept non-whitelisted params' do
    orig_bar_id = Bar.last.id
    foobar = Foobar.create(bar_id: orig_bar_id)
    bar_id = Bar.first.id
    begin
      patch "/example/alpha/awesome_routing_scope/foobars/#{foobar.id}.json", foobar: {bar_id: bar_id}
      fail 'should have raised for non-whitelisted param'
    rescue ::ActionController::UnpermittedParameters
    end
    assert_equal orig_bar_id, Foobar.find(foobar.id).bar_id, "should not have updated with non-whitelisted param. expected #{orig_bar_id} but bar_id was #{Foobar.find(foobar.id).bar_id}"
  end

  test 'update does not accept whitelisted params when cancan disallows user' do
    $test_role = 'nobody'
    foobar = Foobar.create(foo_id: Foo.last.id)
    orig_foo_id = Foo.last.id
    foo_id = Foo.first.id
    begin
      patch "/example/alpha/awesome_routing_scope/foobars/#{foobar.id}.json", foobar: {foo_id: foo_id}
      fail "cancan should not allow put" if response.status < 400
    rescue
    end
    assert_equal foobar.foo_id, Foobar.find(foobar.id).foo_id, "should not have updated with whitelisted param when cancan disallows user"
  end

  test 'update fails with HTTP 404 for missing record' do
    begin
      patch "/example/alpha/awesome_routing_scope/foobars/9999999.json", foobar: {foo_id: Foo.first.id}
      fail "should have raised error"
    rescue
      assert_nil Foobar.where(id: '9999999').first, "should not have created record"
    end
  end

  test 'destroy allowed for accepted id' do
    foobar = Foobar.create(foo_id: Foo.last.id)
    delete "/example/alpha/awesome_routing_scope/foobars/#{foobar.id}.json"
    assert_match '', response.body
    # returns 204, which is a bug, imo. if destroy didn't fail, shouldn't be pointing at a resource.
    assert_includes 200..299, response.status, "destroy returned unexpected response code (got #{response.status}): #{response.body}"
  end

  # This is a bug with IR, imo. RESTful DELETE should not fail with missing record error. :(
  #
  #test 'destroy is idempotent and should not fail for missing record' do
  #  delete "/example/alpha/awesome_routing_scope/foobars/9999999.json"
  #  assert_match '', response.body
  #  assert_equal response.status, 200, "destroy returned unexpected response code (got #{response.status}): #{response.body}"
  #end

  test 'destroy should fail with error if subclass of standard error' do
    begin
      foobar = Foobar.create(foo_id: Foo.last.id)
      # expect this to make destroy fail and reset in after hook
      $error_to_raise_on_next_save_or_destroy_only = SomeSubtypeOfStandardError.new("some type of standard error")
      delete "/example/alpha/awesome_routing_scope/foobars/#{foobar.id}.json"
      fail "should have raised error"
    rescue
    end
  end
end
