require File.dirname(__FILE__) + '/helper'

class TestOoyalaApi < Test::Unit::TestCase
  include RR::Adapters::TestUnit

  def setup
    @api_key    = '7ab06'
    @secret_key = '329b5b204d0f11e0a2d060334bfffe90ab18xqh5'
    @ooyala_api = Ooyala::API.new(@api_key, @secret_key)
    @request    = {:method => "GET", :url => "http://example.com"}
  end
  
  def test_initialization
    assert_equal @api_key, @ooyala_api.api_key
    assert_equal @secret_key, @ooyala_api.secret_key
    assert_equal Ooyala::API::DEFAULT_BASE_URL, @ooyala_api.base_url
    assert_equal Ooyala::API::DEFAULT_EXPIRATION_WINDOW,
        @ooyala_api.expiration_window
  end

  def test_initialization_with_options
    ooyala_api = Ooyala::API.new(@api_key, @secret_key,
                                 :base_url          => 'http://api.ooyala.com',
                                 :cache_base_url    => 'http://api.ooyala.com',
                                 :expiration_window => 1)
    assert_equal 1, ooyala_api.expiration_window
    assert_equal 'http://api.ooyala.com', ooyala_api.base_url
    assert_equal 'http://api.ooyala.com', ooyala_api.cache_base_url
  end

  def test_generate_signature
    assert_equal 'OugvH8gjMEqhq8nyoJQeBtSI57nMbIOp%2B7KGaxx9v8I',
      @ooyala_api.generate_signature('get', '/v2/players/HbxJKM')
  end

  def test_generate_signature_with_query_params
    params = {:api_key => @api_key, 'expires' => '1299991855'}
    assert_equal 'p9DG%2F%2BummS0YcTNOYHtykdjw5N2n5s81OigJfdgHPTA',
      @ooyala_api.generate_signature('GET', '/v2/players/HbxJKM', params)
    params = {'api_key' => @api_key, :expires => '1299991855'}
    assert_equal 'p9DG%2F%2BummS0YcTNOYHtykdjw5N2n5s81OigJfdgHPTA',
      @ooyala_api.generate_signature('GET', '/v2/players/HbxJKM', params)
  end

  def test_generate_signature_with_payload
    params = {'api_key' => @api_key, :expires => '1299991855'}
    body   = 'test'
    path   = '/v2/players/HbxJKM'
    assert_equal @ooyala_api.generate_signature('post', path, params, body),
      'fJrWCcIqeRBZUqa61OV%2B6XOWfpkab6RdW5hJZmZh1CI'
  end

  def test_build_url
    url = @ooyala_api.build_url 'GET', '/v2/players/HbxJKM'
    assert url.include?('https://cdn.api.ooyala.com/')
    assert url.include?('/v2/players/HbxJKM')
    url = @ooyala_api.build_url 'POST', '/v2/players/HbxJKM',
      {:test => true, 'a' => 'b'}
    assert url.include?('https://api.ooyala.com/')
    assert url.include?('test=true')
    assert url.include?('a=b')
  end

  def test_build_url_overriding_base_url
    @ooyala_api.base_url = 'http://example.com'
    url = @ooyala_api.build_url 'POST', '/v2/players/HbxJKM'
    assert url.include?('http://example.com')
    @ooyala_api.cache_base_url = 'http://example.com'
    url = @ooyala_api.build_url 'GET', '/v2/players/HbxJKM'
    assert url.include?('http://example.com')
  end

  def test_send_request_with_method_not_supported
    assert_raise(Ooyala::MethodNotSupportedException) do
      @ooyala_api.send_request(:invalid, '/')
    end
  end

  def test_send_request_with_a_request_error
    req = RestClient::Request.new(@request)
    mock(RestClient::Request).new.with_any_args { req }
    mock(req).execute { raise RestClient::Exception.new }
    assert_raise(Ooyala::RequestErrorException) do
      @ooyala_api.send_request 'get', '/v2/players/HbxJKM'
    end
  end

  def test_send_request
    req = RestClient::Request.new(@request)
    res = RestClient::Response
    mock(RestClient::Request).new.with_any_args { req }
    mock(req).execute { res }
    mock(res).body.twice { '{"test":true}' }
    response = @ooyala_api.send_request 'get', '/v2/players/HbxJKM'
    assert response['test']
  end

  def test_send_request_should_escape_query_parameters
    req = RestClient::Request.new(@request)
    res = RestClient::Response
    mock(RestClient::Request).new.with_any_args do |*args|
      assert args.first[:url].include?(
        "https://cdn.api.ooyala.com/v2/players/HbxJKM")
      assert args.first[:url].include?("test=%27tr+ue%27")
      assert args.first[:url].include?("other=1")
      req
    end
    mock(req).execute { res }
    mock(res).body.twice { '{"test":true}' }
    @ooyala_api.send_request 'get', '/v2/players/HbxJKM',
      {:test => "'tr ue'", :other => 1}
  end

  def test_send_request_should_complete_the_route
    req = RestClient::Request.new(@request)
    res = RestClient::Response
    mock(RestClient::Request).new.with_any_args do |*args|
      assert args.first[:url].include?(
        "https://cdn.api.ooyala.com/v2/players/HbxJKM")
      req
    end
    mock(req).execute { res }
    mock(res).body.twice { '{"test":true}' }
    @ooyala_api.send_request :get, 'players/HbxJKM'
  end

  def test_send_request_should_add_needed_params
    req = RestClient::Request.new(@request)
    res = RestClient::Response
    mock(RestClient::Request).new.with_any_args do |*args|
      assert args.first[:url].include?("api_key=#{@api_key}")
      assert args.first[:url].include?("signature=")
      req
    end
    mock(req).execute { res }
    mock(res).body.twice { '{"test":true}' }
    @ooyala_api.send_request 'GET', 'players/HbxJKM'
  end

  def test_send_request_with_payload
    req = RestClient::Request.new(@request)
    res = RestClient::Response
    mock(RestClient::Request).new.with_any_args do |*args|
      assert_equal "payload", args.first[:payload]
      req
    end
    mock(req).execute { res }
    mock(res).body.twice { '{"test":true}' }
    @ooyala_api.send_request :post, 'players/HbxJKM', {}, 'payload'
  end

  def test_get
    mock(@ooyala_api).send_request('GET', 'test', {}) { true }
    assert @ooyala_api.get('test')
  end

  def test_get_with_params
    mock(@ooyala_api).send_request('GET', 'test', {:test => true, 'a' => 1}) do
      true
    end
    assert @ooyala_api.get('test', :test => true, 'a' => 1)
  end

  def test_post
    mock(@ooyala_api).send_request('POST', 'test', {}, '{"test":true}') { true }
    assert @ooyala_api.post('test', {:test => true})
    mock(@ooyala_api).send_request('POST', 'test', {}, '[1,2,3]') { true }
    assert @ooyala_api.post('test', [1,2,3])
  end

  def test_post_with_params
    mock(@ooyala_api).send_request('POST', 'test', {:test => true},
                                   '{"test":true}') { true }
    assert @ooyala_api.post('test', {:test => true}, :test => true)
  end

  def test_post_with_a_file
    file = File.new(__FILE__)
    mock(file).read { "payload" }
    mock(@ooyala_api).send_request('POST', 'test', {}, 'payload') { true }
    assert @ooyala_api.post('test', file)
  end

  def test_post_with_a_string
    mock(@ooyala_api).send_request('POST', 'test', {}, 'payload') { true }
    assert @ooyala_api.post('test', 'payload')
  end

  def test_put
    mock(@ooyala_api).send_request('PUT', 'test', {}, '{"test":true}') { true }
    assert @ooyala_api.put('test', {:test => true})
    mock(@ooyala_api).send_request('PUT', 'test', {}, '[1,2,3]') { true }
    assert @ooyala_api.put('test', [1,2,3])
  end

  def test_put_with_params
    mock(@ooyala_api).send_request('PUT', 'test', {:test => true},
                                   '{"test":true}') { true }
    assert @ooyala_api.put('test', {:test => true}, :test => true)
  end

  def test_put_with_a_file
    file = File.new(__FILE__)
    mock(file).read { "payload" }
    mock(@ooyala_api).send_request('PUT', 'test', {}, 'payload') { true }
    assert @ooyala_api.put('test', file)
  end

  def test_put_with_a_string
    mock(@ooyala_api).send_request('PUT', 'test', {}, 'payload') { true }
    assert @ooyala_api.put('test', 'payload')
  end

  def test_patch
    mock(@ooyala_api).send_request('PATCH', 'test', {}, '{"test":true}') { true }
    assert @ooyala_api.patch('test', {:test => true})
    mock(@ooyala_api).send_request('PATCH', 'test', {}, '[1,2,3]') { true }
    assert @ooyala_api.patch('test', [1,2,3])
  end

  def test_patch_with_params
    mock(@ooyala_api).send_request('PATCH', 'test', {:test => true},
                                   '{"test":true}') { true }
    assert @ooyala_api.patch('test', {:test => true}, :test => true)
  end

  def test_delete
    mock(@ooyala_api).send_request('DELETE', 'test', {}) { true }
    assert @ooyala_api.delete('test')
  end

  def test_delete_with_params
    mock(@ooyala_api).send_request('DELETE', 'test', {:test => true, 'a' => 1}) do
      true
    end
    assert @ooyala_api.delete('test', :test => true, 'a' => 1)
  end
end
