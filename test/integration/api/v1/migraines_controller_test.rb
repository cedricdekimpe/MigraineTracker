# frozen_string_literal: true

require "test_helper"

class Api::V1::MigrainesControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @user = users(:one)
    @token = nil
    @migraine = migraines(:one)
  end

  def authenticated_token
    @token ||= login_user(@user.email, "password123")
  end

  # ===============
  # Index
  # ===============

  test "index returns paginated migraines" do
    get "/api/v1/migraines", headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_collection("migraine")
    assert json_response[:meta].present?
    assert json_response[:links].present?
  end

  test "index filters by year" do
    get "/api/v1/migraines",
      params: { year: Date.current.year },
      headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_collection("migraine")
  end

  test "index fails without authentication" do
    get "/api/v1/migraines", headers: api_headers

    assert_response :unauthorized
  end

  # ===============
  # Show
  # ===============

  test "show returns migraine details" do
    get "/api/v1/migraines/#{@migraine.id}", headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_resource("migraine", @migraine.id)
    assert json_response[:data][:attributes][:occurred_on].present?
  end

  test "show fails for non-existent migraine" do
    get "/api/v1/migraines/999999", headers: api_headers(authenticated_token)

    assert_response :not_found
  end

  test "show fails for another user's migraine" do
    other_migraine = migraines(:four) # belongs to user two

    get "/api/v1/migraines/#{other_migraine.id}", headers: api_headers(authenticated_token)

    assert_response :not_found
  end

  # ===============
  # Create
  # ===============

  test "create creates a new migraine" do
    assert_difference("@user.migraines.count", 1) do
      post "/api/v1/migraines",
        params: {
          occurred_on: Date.current.iso8601,
          nature: "M",
          intensity: 4,
          on_period: false
        }.to_json,
        headers: api_headers(authenticated_token)
    end

    assert_response :created
    assert_json_api_resource("migraine")
  end

  test "create with medication" do
    medication = medications(:one)

    post "/api/v1/migraines",
      params: {
        occurred_on: (Date.current - 1.day).iso8601,
        nature: "H",
        intensity: 3,
        on_period: true,
        medication_id: medication.id
      }.to_json,
      headers: api_headers(authenticated_token)

    assert_response :created
    assert_equal medication.id.to_s, json_response[:data][:relationships][:medication][:data][:id]
  end

  test "create fails with invalid params" do
    post "/api/v1/migraines",
      params: { nature: "M" }.to_json,
      headers: api_headers(authenticated_token)

    assert_response :unprocessable_entity
    assert json_response[:errors].present?
  end

  test "create fails without authentication" do
    post "/api/v1/migraines",
      params: { occurred_on: Date.current.iso8601, nature: "M", intensity: 3 }.to_json,
      headers: api_headers

    assert_response :unauthorized
  end

  # ===============
  # Update
  # ===============

  test "update modifies migraine" do
    patch "/api/v1/migraines/#{@migraine.id}",
      params: { intensity: 5, on_period: true }.to_json,
      headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_resource("migraine", @migraine.id)
    assert_equal 5, json_response[:data][:attributes][:intensity]
    assert_equal true, json_response[:data][:attributes][:on_period]
  end

  test "update fails for another user's migraine" do
    other_migraine = migraines(:four)

    patch "/api/v1/migraines/#{other_migraine.id}",
      params: { intensity: 5 }.to_json,
      headers: api_headers(authenticated_token)

    assert_response :not_found
  end

  # ===============
  # Destroy
  # ===============

  test "destroy deletes migraine" do
    assert_difference("@user.migraines.count", -1) do
      delete "/api/v1/migraines/#{@migraine.id}", headers: api_headers(authenticated_token)
    end

    assert_response :no_content
  end

  test "destroy fails for another user's migraine" do
    other_migraine = migraines(:four)

    assert_no_difference("Migraine.count") do
      delete "/api/v1/migraines/#{other_migraine.id}", headers: api_headers(authenticated_token)
    end

    assert_response :not_found
  end

  # ===============
  # Calendar
  # ===============

  test "calendar returns migraines for current month" do
    get "/api/v1/migraines/calendar", headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_collection("migraine")
    assert json_response[:meta][:month].present?
    assert json_response[:meta][:year].present?
  end

  test "calendar filters by month and year" do
    get "/api/v1/migraines/calendar",
      params: { month: "2025-01" },
      headers: api_headers(authenticated_token)

    assert_response :success
    assert_equal 1, json_response[:meta][:month]
    assert_equal 2025, json_response[:meta][:year]
  end

  # ===============
  # Yearly
  # ===============

  test "yearly returns migraines for current year" do
    get "/api/v1/migraines/yearly", headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_collection("migraine")
    assert json_response[:meta][:year].present?
    assert json_response[:meta][:total_count].present?
  end

  test "yearly filters by year" do
    get "/api/v1/migraines/yearly",
      params: { year: 2025 },
      headers: api_headers(authenticated_token)

    assert_response :success
    assert_equal 2025, json_response[:meta][:year]
  end
end
