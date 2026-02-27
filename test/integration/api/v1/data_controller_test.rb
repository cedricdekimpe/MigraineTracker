# frozen_string_literal: true

require "test_helper"

class Api::V1::DataControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @user = users(:one)
    @token = nil
  end

  def authenticated_token
    @token ||= login_user(@user.email, "password123")
  end

  # ===============
  # Export
  # ===============

  test "export returns all user data" do
    get "/api/v1/data/export", headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_resource("export")

    attrs = json_response[:data][:attributes]
    assert attrs[:exported_at].present?
    assert_equal @user.email, attrs[:user_email]
    assert attrs[:medications].is_a?(Array)
    assert attrs[:migraines].is_a?(Array)

    # Check meta info
    assert json_response[:meta][:medications_count].present? || json_response[:meta][:medications_count] == 0
    assert json_response[:meta][:migraines_count].present? || json_response[:meta][:migraines_count] == 0
  end

  test "export includes medication and migraine details" do
    get "/api/v1/data/export", headers: api_headers(authenticated_token)

    assert_response :success

    attrs = json_response[:data][:attributes]

    # Check medications structure
    if attrs[:medications].any?
      med = attrs[:medications].first
      assert med[:name].present?
      assert med[:created_at].present?
    end

    # Check migraines structure
    if attrs[:migraines].any?
      migraine = attrs[:migraines].first
      assert migraine[:occurred_on].present?
      assert migraine.key?(:nature)
      assert migraine.key?(:intensity)
      assert migraine.key?(:on_period)
    end
  end

  test "export fails without authentication" do
    get "/api/v1/data/export", headers: api_headers

    assert_response :unauthorized
  end

  # ===============
  # Import
  # ===============

  test "import creates medications and migraines from export data" do
    # Create a new user for clean import test
    new_user = User.create!(email: "import_test@example.com", password: "password123")
    token = login_user(new_user.email, "password123")

    import_data = {
      data: {
        user_email: new_user.email,
        medications: [
          { name: "Imported Med 1" },
          { name: "Imported Med 2" }
        ],
        migraines: [
          {
            occurred_on: (Date.current - 100.days).iso8601,
            nature: "M",
            intensity: 3,
            on_period: false,
            medication_name: "Imported Med 1"
          },
          {
            occurred_on: (Date.current - 101.days).iso8601,
            nature: "H",
            intensity: 5,
            on_period: true,
            medication_name: nil
          }
        ]
      }
    }

    assert_difference(["new_user.medications.count", "new_user.migraines.count"], 2) do
      post "/api/v1/data/import",
        params: import_data.to_json,
        headers: api_headers(token)
    end

    assert_response :success
    assert_json_api_resource("import_result")

    attrs = json_response[:data][:attributes]
    assert_equal 2, attrs[:medications_imported]
    assert_equal 2, attrs[:migraines_imported]
  end

  test "import skips duplicate medications" do
    # User one already has Ibuprofen
    import_data = {
      data: {
        user_email: @user.email,
        medications: [
          { name: "Ibuprofen" }, # Already exists
          { name: "New Medication" }
        ],
        migraines: []
      }
    }

    assert_difference("@user.medications.count", 1) do
      post "/api/v1/data/import",
        params: import_data.to_json,
        headers: api_headers(authenticated_token)
    end

    assert_response :success
    assert_equal 1, json_response[:data][:attributes][:medications_imported]
  end

  test "import skips duplicate migraines on same date" do
    existing_date = migraines(:one).occurred_on

    import_data = {
      data: {
        user_email: @user.email,
        medications: [],
        migraines: [
          {
            occurred_on: existing_date.iso8601,
            nature: "M",
            intensity: 1,
            on_period: false
          }
        ]
      }
    }

    assert_no_difference("@user.migraines.count") do
      post "/api/v1/data/import",
        params: import_data.to_json,
        headers: api_headers(authenticated_token)
    end

    assert_response :success
    assert_equal 0, json_response[:data][:attributes][:migraines_imported]
  end

  test "import fails with mismatched email" do
    import_data = {
      data: {
        user_email: "different@example.com",
        medications: [],
        migraines: []
      }
    }

    post "/api/v1/data/import",
      params: import_data.to_json,
      headers: api_headers(authenticated_token)

    assert_response :unprocessable_entity
    assert json_response[:errors].present?
  end

  test "import fails without authentication" do
    post "/api/v1/data/import",
      params: { data: {} }.to_json,
      headers: api_headers

    assert_response :unauthorized
  end
end
