class TestArbitrary < MiniTest::Unit::TestCase
  def test_match
    hello, love80, love8080 = router {
      add('test').arbitrary(Proc.new{|req, params| req.rack.host == 'hellodooly' })
      add("test").arbitrary(Proc.new{|req, params| req.rack.host == 'lovelove' }).arbitrary{|req, params| req.rack.port == 80}
      add("test").arbitrary(Proc.new{|req, params| req.rack.host == 'lovelove' }).arbitrary{|req, params| req.rack.port == 8080}
    }
    assert_route love8080, 'http://lovelove:8080/test'
  end

  def test_less_specific_node
    hello, love80, love8080, general = router {
      add("/test").arbitrary(Proc.new{|req, params| req.rack.host == 'hellodooly' })
      add("/test").arbitrary(Proc.new{|req, params| req.rack.host == 'lovelove' }).arbitrary{|req, params| req.rack.port == 80}
      add("/test").arbitrary(Proc.new{|req, params| req.rack.host == 'lovelove' }).arbitrary{|req, params| req.rack.port == 8080}
      add("/test")
    }
    assert_route general,  'http://lovelove:8081/test'
    assert_route hello,    'http://hellodooly:8081/test'
    assert_route love80,   'http://lovelove:80/test'
    assert_route love8080, 'http://lovelove:8080/test'
  end

  def test_match_request
    love80, love8080 = router {
      add("/test").get.arbitrary(Proc.new{|req, params| req.rack.host == 'lovelove' }).arbitrary{|req, params| req.rack.port == 80}
      add("/test").get.arbitrary(Proc.new{|req, params| req.rack.host == 'lovelove' }).arbitrary{|req, params| req.rack.port == 8080}
    }
    assert_route love80,   'http://lovelove:80/test'
    assert_route love8080, 'http://lovelove:8080/test'
  end

  def test_less_specific_with_request
    love80, love8080, general = router {
      add("test").post.arbitrary(Proc.new{|req, params| req.rack.host == 'lovelove' }).arbitrary{|req, params| req.rack.port == 80}
      add("test").post.arbitrary(Proc.new{|req, params| req.rack.host == 'lovelove' }).arbitrary{|req, params| req.rack.port == 8080}
      add("test").post
    }
    assert_route love8080, Rack::MockRequest.env_for('http://lovelove:8080/test', :method => :post)
    assert_route love80,   Rack::MockRequest.env_for('http://lovelove:80/test', :method => :post)
    assert_route general,  Rack::MockRequest.env_for('/test', :method => :post)
  end

  def test_pass_params
    r = router {
      add(":test").get.arbitrary(Proc.new{|req, params, dest| params[:test] == 'test' })
    }
    assert_route r, '/test', {:test => 'test'}
  end

  def test_continue
    no, yes = router {
      add('test').arbitrary_with_continue{|req, p| req.continue[false]}
      add('test').arbitrary_with_continue{|req, p| req.continue[true]}
    }
    assert_route yes, '/test'
  end
end