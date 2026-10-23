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
    assert_equal 4, attrs[:total_episodes]
    assert_equal 2, attrs[:with_medication]
    assert_equal 2, attrs[:without_medication]
    assert_equal 2, attrs[:aura_count]
    assert_equal 1, attrs[:on_period_count]
    assert_in_delta 5.3, attrs[:average_intensity], 0.1
  end

  test "index fails without authentication" do
    get "/api/v1/stats", headers: api_headers

    assert_response :unauthorized
  end

  # ===============
  # Monthly
  # ===============

  test "monthly returns the current month and the previous ones" do
    get "/api/v1/stats/monthly", params: { months: 6 }, headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_resource("monthly_stats")

    months = json_response[:data][:attributes][:months]
    assert_equal 6, months.length
    assert_equal Date.current.strftime("%Y-%m"), months.last[:month]
  end

  test "monthly clamps the months parameter" do
    get "/api/v1/stats/monthly", params: { months: 500 }, headers: api_headers(authenticated_token)

    assert_response :success
    assert_equal 24, json_response[:data][:attributes][:months].length
  end

  # ===============
  # Other breakdowns
  # ===============

  test "by_day_of_week returns all seven days" do
    get "/api/v1/stats/by_day_of_week", headers: api_headers(authenticated_token)

    assert_response :success
    attrs = json_response[:data][:attributes]
    assert_equal 7, attrs[:days].length
    assert_equal 4, attrs[:total]
    assert_equal 4, attrs[:days].sum { |day| day[:count] }
  end

  test "by_medication counts intakes and episodes without medication" do
    get "/api/v1/stats/by_medication", headers: api_headers(authenticated_token)

    assert_response :success
    medications = json_response[:data][:attributes][:medications].index_by { |entry| entry[:name] }
    assert_equal 2, medications["Ibuprofen"][:count]
    assert_equal 1, medications["Paracetamol"][:count]
    assert_equal 2, medications["None"][:count]
  end

  test "by_pain_kind separates migraines, headaches and isolated auras" do
    get "/api/v1/stats/by_pain_kind", headers: api_headers(authenticated_token)

    assert_response :success
    attrs = json_response[:data][:attributes]
    kinds = attrs[:kinds].to_h { |entry| [entry[:kind], entry[:count]] }
    assert_equal({ "migraine" => 2, "headache" => 1, "aura_only" => 1 }, kinds)
    assert_equal 2, attrs[:with_aura]
  end

  test "by_intensity covers 1 to 10 and ignores episodes without pain" do
    get "/api/v1/stats/by_intensity", headers: api_headers(authenticated_token)

    assert_response :success
    attrs = json_response[:data][:attributes]
    assert_equal (1..10).to_a, attrs[:intensities].map { |entry| entry[:intensity] }
    assert_equal 3, attrs[:total]
    assert_equal 1, attrs[:intensities].find { |entry| entry[:intensity] == 7 }[:count]
  end

  test "by_trigger lists trigger frequencies" do
    get "/api/v1/stats/by_trigger", headers: api_headers(authenticated_token)

    assert_response :success
    attrs = json_response[:data][:attributes]
    assert_equal [["Lack of sleep", 1], ["Stress", 1]], attrs[:triggers].map { |entry| [entry[:name], entry[:count]] }
    assert_equal 4, attrs[:total_episodes]
  end

  test "stats never include another user's data" do
    get "/api/v1/stats", headers: api_headers(login_user(users(:two).email, "password456"))

    assert_equal 1, json_response[:data][:attributes][:total_episodes]
  end

  %w[by_day_of_week by_medication by_pain_kind by_intensity by_trigger monthly].each do |endpoint|
    test "#{endpoint} requires authentication" do
      get "/api/v1/stats/#{endpoint}", headers: api_headers
      assert_response :unauthorized
    end
  end
end
