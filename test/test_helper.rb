ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end

# API integration test helpers
module ApiTestHelper
  def json_response
    @json_response ||= JSON.parse(response.body, symbolize_names: true)
  end

  def api_headers(token = nil)
    headers = {
      'Accept' => 'application/vnd.api+json',
      'Content-Type' => 'application/json'
    }
    headers['Authorization'] = "Bearer #{token}" if token
    headers
  end

  def login_user(email, password)
    post '/api/v1/auth/login',
      params: { email: email, password: password }.to_json,
      headers: api_headers

    assert_response :success
    response.headers['Authorization']&.sub('Bearer ', '')
  end

  def assert_json_api_error(status_code, title = nil)
    assert_response status_code
    assert json_response[:errors].present?, "Expected errors in response"
    assert_equal status_code.to_s, json_response[:errors].first[:status] if title
  end

  def assert_json_api_resource(type, id = nil)
    assert json_response[:data].present?, "Expected data in response"
    assert_equal type.to_s, json_response[:data][:type]
    assert_equal id.to_s, json_response[:data][:id] if id
  end

  def assert_json_api_collection(type)
    assert json_response[:data].is_a?(Array), "Expected array in data"
    json_response[:data].each do |item|
      assert_equal type.to_s, item[:type]
    end
  end
end

