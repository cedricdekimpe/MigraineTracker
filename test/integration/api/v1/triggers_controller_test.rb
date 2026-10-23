# frozen_string_literal: true

require "test_helper"

class Api::V1::TriggersControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @user = users(:one)
    @token = nil
  end

  def authenticated_token
    @token ||= login_user(@user.email, "password123")
  end

  test "index lists the user's triggers alphabetically with usage" do
    get "/api/v1/triggers", headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_collection("trigger")
    assert_equal ["Lack of sleep", "Stress"], json_response[:data].map { |t| t[:attributes][:name] }
    assert_equal 1, json_response[:data].first[:attributes][:episodes_count]
  end

  test "create, update and destroy" do
    post "/api/v1/triggers", params: { name: "Chocolate" }.to_json, headers: api_headers(authenticated_token)
    assert_response :created
    id = json_response[:data][:id]

    patch "/api/v1/triggers/#{id}", params: { name: "Dark chocolate" }.to_json, headers: api_headers(authenticated_token)
    assert_response :success
    assert_equal "Dark chocolate", Trigger.find(id).name

    delete "/api/v1/triggers/#{id}", headers: api_headers(authenticated_token)
    assert_response :no_content
    assert_not Trigger.exists?(id)
  end

  test "create rejects duplicates ignoring case and blank names" do
    post "/api/v1/triggers", params: { name: "STRESS" }.to_json, headers: api_headers(authenticated_token)
    assert_response :unprocessable_entity

    post "/api/v1/triggers", params: { name: "  " }.to_json, headers: api_headers(authenticated_token)
    assert_response :unprocessable_entity
  end

  test "cannot touch another user's trigger" do
    other = triggers(:other_users_trigger)

    patch "/api/v1/triggers/#{other.id}", params: { name: "Mine" }.to_json, headers: api_headers(authenticated_token)
    assert_response :not_found
    delete "/api/v1/triggers/#{other.id}", headers: api_headers(authenticated_token)
    assert_response :not_found
  end

  test "requires authentication" do
    get "/api/v1/triggers", headers: api_headers
    assert_response :unauthorized
  end
end
