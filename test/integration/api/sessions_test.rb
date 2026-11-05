require "test_helper"

class Api::SessionsTest < ActionDispatch::IntegrationTest
  def sign_in_device(email: "user@example.com", password: "password123", name: "Pixel 8")
    post api_v1_session_path, params: { email: email, password: password, device_name: name }.to_json,
      headers: { "Content-Type" => "application/json" }
  end

  def auth(token) = { "Authorization" => "Bearer #{token}" }

  test "a device signs in with the account's password and gets a token, kept only as a digest" do
    assert_difference -> { users(:one).api_tokens.count }, 1 do
      sign_in_device
    end
    assert_response :created
    token = response.parsed_body["token"]
    assert token.length >= 32
    assert_equal "user@example.com", response.parsed_body.dig("user", "email")

    device = users(:one).api_tokens.last
    assert_equal "Pixel 8", device.name
    assert_not_equal token, device.token_digest
    assert_not ApiToken.exists?(token_digest: token)
  end

  test "a wrong password and an unknown address get the same answer" do
    sign_in_device(password: "wrong")
    wrong_password = [ response.status, response.body ]
    sign_in_device(email: "nobody@example.com")
    assert_equal wrong_password, [ response.status, response.body ]
    assert_response :unauthorized
    assert_equal "invalid_credentials", response.parsed_body["error"]
  end

  test "the token opens the API until the device signs out" do
    sign_in_device
    token = response.parsed_body["token"]

    get api_v1_me_path, headers: auth(token)
    assert_response :success
    assert_equal "user@example.com", response.parsed_body.dig("user", "email")

    delete api_v1_session_path, headers: auth(token)
    assert_response :no_content
    get api_v1_me_path, headers: auth(token)
    assert_response :unauthorized
  end

  test "no token, a bad token or a malformed header are refused" do
    get api_v1_changes_path
    assert_response :unauthorized
    get api_v1_changes_path, headers: auth("not-a-token")
    assert_response :unauthorized
    get api_v1_changes_path, headers: { "Authorization" => "Token abc" }
    assert_response :unauthorized
  end

  test "a body that is not a JSON object is a bad request" do
    post api_v1_session_path, params: "[1, 2]", headers: { "Content-Type" => "application/json" }
    assert_response :bad_request
    post api_v1_session_path, params: "{oops", headers: { "Content-Type" => "application/json" }
    assert_response :bad_request
  end

  test "sign-ins of the API are throttled per IP and per address" do
    travel_to Time.zone.local(2026, 1, 1, 12, 0, 1)
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    8.times { sign_in_device(password: "wrong") }
    assert_response :unauthorized
    sign_in_device(password: "wrong")
    assert_response :too_many_requests
  ensure
    travel_back
    Rack::Attack.cache.store = Rails.cache
  end

  test "deleting the account deletes its devices" do
    _device, token = ApiToken.issue(users(:one), name: "Phone")
    users(:one).destroy!
    assert_not ApiToken.authenticate(token)
  end
end
