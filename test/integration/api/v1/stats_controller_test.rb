# frozen_string_literal: true

require "test_helper"

class Api::V1::StatsControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @user = users(:one)
    @token = nil
  end

  def authenticated_token
    @token ||= login_user(@user.email, "password123")
  end

  # ===============
  # Index
  # ===============

  test "index returns overall stats" do
    get "/api/v1/stats", headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_resource("stats")

    attrs = json_response[:data][:attributes]
    assert attrs[:total_migraines].present? || attrs[:total_migraines] == 0
    assert attrs.key?(:with_medication)
    assert attrs.key?(:without_medication)
    assert attrs.key?(:average_intensity)
  end

  test "index fails without authentication" do
    get "/api/v1/stats", headers: api_headers

    assert_response :unauthorized
  end

  # ===============
  # Monthly
  # ===============

  test "monthly returns monthly breakdown" do
    get "/api/v1/stats/monthly", headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_resource("monthly_stats")

    attrs = json_response[:data][:attributes]
    assert attrs[:months].is_a?(Array)
    assert attrs[:months].first.key?(:month) if attrs[:months].any?
  end

  test "monthly accepts months parameter" do
    get "/api/v1/stats/monthly",
      params: { months: 6 },
      headers: api_headers(authenticated_token)

    assert_response :success
    assert json_response[:data][:attributes][:months].length <= 6
  end

  # ===============
  # By Day of Week
  # ===============

  test "by_day_of_week returns weekday distribution" do
    get "/api/v1/stats/by_day_of_week", headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_resource("day_of_week_stats")

    attrs = json_response[:data][:attributes]
    assert attrs[:days].is_a?(Array)
    assert_equal 7, attrs[:days].length
  end

  # ===============
  # By Medication
  # ===============

  test "by_medication returns medication usage stats" do
    get "/api/v1/stats/by_medication", headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_resource("medication_stats")

    attrs = json_response[:data][:attributes]
    assert attrs[:medications].is_a?(Array)
    assert attrs.key?(:total)
  end

  # ===============
  # By Nature
  # ===============

  test "by_nature returns nature distribution" do
    get "/api/v1/stats/by_nature", headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_resource("nature_stats")

    attrs = json_response[:data][:attributes]
    assert attrs[:natures].is_a?(Array)
  end

  # ===============
  # By Intensity
  # ===============

  test "by_intensity returns intensity distribution" do
    get "/api/v1/stats/by_intensity", headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_resource("intensity_stats")

    attrs = json_response[:data][:attributes]
    assert attrs[:intensities].is_a?(Array)
    assert attrs.key?(:average)
  end
end
