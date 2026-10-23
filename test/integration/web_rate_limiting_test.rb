require "test_helper"

class WebRateLimitingTest < ActionDispatch::IntegrationTest
  setup do
    # Counters live in one-minute windows: stay inside one so a test cannot straddle two of them
    travel_to Time.zone.local(2026, 1, 1, 12, 0, 1)
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    travel_back
    Rack::Attack.cache.store = Rails.cache
  end

  def sign_in_attempt(email, ip: "203.0.113.10", path: "/users/sign_in", password: "wrong-password")
    post path,
      params: { user: { email: email, password: password } },
      env: { "REMOTE_ADDR" => ip }
  end

  test "sign-in is throttled per IP" do
    10.times do |i|
      sign_in_attempt("person#{i}@example.com")
      assert_not_equal 429, response.status, "attempt #{i + 1} should not be throttled"
    end

    sign_in_attempt("person-11@example.com")
    assert_response :too_many_requests
    assert_match(/Too many attempts/, response.body)
    assert_equal "text/plain; charset=utf-8", response.headers["Content-Type"]
    assert response.headers["Retry-After"].to_i.positive?
  end

  test "sign-in is throttled per targeted account across different IPs" do
    8.times do |i|
      sign_in_attempt("victim@example.com", ip: "198.51.100.#{i + 1}")
      assert_not_equal 429, response.status
    end

    sign_in_attempt("victim@example.com", ip: "198.51.100.200")
    assert_response :too_many_requests
  end

  test "email throttle ignores case, whitespace and locale prefix" do
    4.times { |i| sign_in_attempt("Victim@Example.com", ip: "198.51.100.#{i + 1}") }
    4.times { |i| sign_in_attempt("  victim@example.com ", ip: "198.51.100.#{i + 10}", path: "/fr/users/sign_in") }

    sign_in_attempt("victim@example.com", ip: "198.51.100.99")
    assert_response :too_many_requests
  end

  test "throttled responses are in French under /fr" do
    10.times { |i| sign_in_attempt("p#{i}@example.com", path: "/fr/users/sign_in") }
    sign_in_attempt("p-last@example.com", path: "/fr/users/sign_in")

    assert_response :too_many_requests
    assert_match(/Trop de tentatives/, response.body)
  end

  test "a legitimate sign-in still works and viewing the form is never throttled" do
    15.times { get "/users/sign_in", env: { "REMOTE_ADDR" => "203.0.113.50" } }
    assert_response :success

    sign_in_attempt("user@example.com", ip: "203.0.113.51", password: "password123")
    assert_response :redirect
  end

  test "password reset requests are limited per address and per IP" do
    3.times do |i|
      post "/users/password", params: { user: { email: "target@example.com" } }, env: { "REMOTE_ADDR" => "192.0.2.#{i + 1}" }
      assert_not_equal 429, response.status
    end

    post "/users/password", params: { user: { email: "target@example.com" } }, env: { "REMOTE_ADDR" => "192.0.2.100" }
    assert_response :too_many_requests

    5.times { |i| post "/users/password", params: { user: { email: "other#{i}@example.com" } }, env: { "REMOTE_ADDR" => "192.0.2.200" } }
    post "/users/password", params: { user: { email: "other-last@example.com" } }, env: { "REMOTE_ADDR" => "192.0.2.200" }
    assert_response :too_many_requests
  end

  test "sign-ups are limited per IP" do
    10.times do |i|
      post "/users", params: { user: { email: "new#{i}@example.com", password: "x" } }, env: { "REMOTE_ADDR" => "192.0.2.60" }
      assert_not_equal 429, response.status
    end

    post "/users", params: { user: { email: "new-last@example.com", password: "x" } }, env: { "REMOTE_ADDR" => "192.0.2.60" }
    assert_response :too_many_requests
  end

  test "account update and deletion are limited per IP" do
    10.times { delete "/users", params: { password: "guess" }, env: { "REMOTE_ADDR" => "192.0.2.70" } }

    delete "/users", params: { password: "guess" }, env: { "REMOTE_ADDR" => "192.0.2.70" }
    assert_response :too_many_requests
  end

  test "unparsable parameters do not crash the throttle" do
    post "/users/sign_in", params: "user=notahash&user[email]=x", env: { "REMOTE_ADDR" => "192.0.2.80" }
    assert_not_equal 500, response.status
  end
end
