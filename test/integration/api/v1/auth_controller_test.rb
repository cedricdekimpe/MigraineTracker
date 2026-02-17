# frozen_string_literal: true

require "test_helper"

class Api::V1::AuthControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @user = users(:one)
  end

  # ===============
  # Registration
  # ===============

  test "register creates a new user with valid params" do
    assert_difference("User.count", 1) do
      post "/api/v1/auth/register",
        params: {
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123"
        }.to_json,
        headers: api_headers
    end

    assert_response :created
    assert_json_api_resource("user")
    assert_equal "newuser@example.com", json_response[:data][:attributes][:email]
    assert response.headers["Authorization"].present?
  end

  test "register fails with missing email" do
    assert_no_difference("User.count") do
      post "/api/v1/auth/register",
        params: {
          password: "password123",
          password_confirmation: "password123"
        }.to_json,
        headers: api_headers
    end

    assert_response :unprocessable_entity
    assert json_response[:errors].present?
  end

  test "register fails with duplicate email" do
    assert_no_difference("User.count") do
      post "/api/v1/auth/register",
        params: {
          email: @user.email,
          password: "password123",
          password_confirmation: "password123"
        }.to_json,
        headers: api_headers
    end

    assert_response :unprocessable_entity
    assert json_response[:errors].present?
  end

  test "register fails with password mismatch" do
    assert_no_difference("User.count") do
      post "/api/v1/auth/register",
        params: {
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "different"
        }.to_json,
        headers: api_headers
    end

    assert_response :unprocessable_entity
  end

  # ===============
  # Login
  # ===============

  test "login returns JWT token with valid credentials" do
    post "/api/v1/auth/login",
      params: { email: @user.email, password: "password123" }.to_json,
      headers: api_headers

    assert_response :success
    assert_json_api_resource("user")
    assert response.headers["Authorization"].present?
    assert response.headers["Authorization"].start_with?("Bearer ")
  end

  test "login fails with invalid password" do
    post "/api/v1/auth/login",
      params: { email: @user.email, password: "wrongpassword" }.to_json,
      headers: api_headers

    assert_response :unauthorized
    assert json_response[:errors].present?
  end

  test "login fails with non-existent email" do
    post "/api/v1/auth/login",
      params: { email: "nonexistent@example.com", password: "password123" }.to_json,
      headers: api_headers

    assert_response :unauthorized
  end

  # ===============
  # Logout
  # ===============

  test "logout revokes JWT token" do
    token = login_user(@user.email, "password123")

    delete "/api/v1/auth/logout", headers: api_headers(token)

    assert_response :success
    assert json_response[:meta][:message].present?

    # Verify token is revoked by trying to use it
    get "/api/v1/auth/me", headers: api_headers(token)
    assert_response :unauthorized
  end

  test "logout fails without authentication" do
    delete "/api/v1/auth/logout", headers: api_headers

    assert_response :unauthorized
  end

  # ===============
  # Me
  # ===============

  test "me returns current user info" do
    token = login_user(@user.email, "password123")

    get "/api/v1/auth/me", headers: api_headers(token)

    assert_response :success
    assert_json_api_resource("user")
    assert_equal @user.email, json_response[:data][:attributes][:email]
  end

  test "me fails without authentication" do
    get "/api/v1/auth/me", headers: api_headers

    assert_response :unauthorized
  end

  # ===============
  # Refresh
  # ===============

  test "refresh returns new JWT token" do
    token = login_user(@user.email, "password123")

    post "/api/v1/auth/refresh", headers: api_headers(token)

    assert_response :success
    assert response.headers["Authorization"].present?
    new_token = response.headers["Authorization"].sub("Bearer ", "")
    assert_not_equal token, new_token
  end

  test "refresh fails without authentication" do
    post "/api/v1/auth/refresh", headers: api_headers

    assert_response :unauthorized
  end
end
