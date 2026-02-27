# frozen_string_literal: true

require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @user = users(:one)
    @token = nil
  end

  def authenticated_token
    @token ||= login_user(@user.email, "password123")
  end

  # ===============
  # Show Profile
  # ===============

  test "show returns user profile" do
    get "/api/v1/user/profile", headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_resource("user")
    assert_equal @user.email, json_response[:data][:attributes][:email]
  end

  test "show fails without authentication" do
    get "/api/v1/user/profile", headers: api_headers

    assert_response :unauthorized
  end

  # ===============
  # Update Profile
  # ===============

  test "update changes email" do
    patch "/api/v1/user/profile",
      params: { email: "updated@example.com" }.to_json,
      headers: api_headers(authenticated_token)

    assert_response :success
    assert_equal "updated@example.com", json_response[:data][:attributes][:email]
    assert_equal "updated@example.com", @user.reload.email
  end

  test "update changes password with current_password" do
    patch "/api/v1/user/profile",
      params: {
        current_password: "password123",
        password: "newpassword456",
        password_confirmation: "newpassword456"
      }.to_json,
      headers: api_headers(authenticated_token)

    assert_response :success

    # Verify new password works
    post "/api/v1/auth/login",
      params: { email: @user.email, password: "newpassword456" }.to_json,
      headers: api_headers

    assert_response :success
  end

  test "update fails with incorrect current_password" do
    patch "/api/v1/user/profile",
      params: {
        current_password: "wrongpassword",
        password: "newpassword456",
        password_confirmation: "newpassword456"
      }.to_json,
      headers: api_headers(authenticated_token)

    assert_response :unprocessable_entity
    assert json_response[:errors].present?
  end

  test "update fails with invalid email" do
    patch "/api/v1/user/profile",
      params: { email: "not-an-email" }.to_json,
      headers: api_headers(authenticated_token)

    assert_response :unprocessable_entity
  end

  test "update fails without authentication" do
    patch "/api/v1/user/profile",
      params: { email: "hacker@example.com" }.to_json,
      headers: api_headers

    assert_response :unauthorized
  end

  # ===============
  # Destroy Account
  # ===============

  test "destroy deletes user account with confirmation" do
    # Create a user to delete to avoid breaking other tests
    user_to_delete = User.create!(email: "delete_me@example.com", password: "password123")
    token = login_user(user_to_delete.email, "password123")

    assert_difference("User.count", -1) do
      delete "/api/v1/user",
        params: {
          confirmation_phrase: "DELETE MY ACCOUNT",
          password: "password123"
        }.to_json,
        headers: api_headers(token)
    end

    assert_response :success
    assert json_response[:meta][:message].present?
  end

  test "destroy fails with wrong confirmation phrase" do
    delete "/api/v1/user",
      params: {
        confirmation_phrase: "delete my account", # lowercase
        password: "password123"
      }.to_json,
      headers: api_headers(authenticated_token)

    assert_response :unprocessable_entity
    assert json_response[:errors].present?
    assert User.exists?(@user.id)
  end

  test "destroy fails with wrong password" do
    delete "/api/v1/user",
      params: {
        confirmation_phrase: "DELETE MY ACCOUNT",
        password: "wrongpassword"
      }.to_json,
      headers: api_headers(authenticated_token)

    assert_response :unprocessable_entity
    assert User.exists?(@user.id)
  end

  test "destroy fails without authentication" do
    delete "/api/v1/user",
      params: {
        confirmation_phrase: "DELETE MY ACCOUNT",
        password: "password123"
      }.to_json,
      headers: api_headers

    assert_response :unauthorized
  end

  test "destroy deletes all associated data" do
    # Create user with data
    user = User.create!(email: "full_delete@example.com", password: "password123")
    medication = user.medications.create!(name: "Test Med")
    user.migraines.create!(occurred_on: Date.current - 500.days, nature: "M", intensity: 3, medication: medication)

    token = login_user(user.email, "password123")

    user_count_before = User.count
    med_count_before = user.medications.count
    migraine_count_before = user.migraines.count

    delete "/api/v1/user",
      params: {
        confirmation_phrase: "DELETE MY ACCOUNT",
        password: "password123"
      }.to_json,
      headers: api_headers(token)

    assert_response :success
    assert_equal user_count_before - 1, User.count
    assert_equal 0, Medication.where(user_id: user.id).count
    assert_equal 0, Migraine.where(user_id: user.id).count
  end
end
