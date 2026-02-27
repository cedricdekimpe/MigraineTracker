# frozen_string_literal: true

require "test_helper"

class Api::V1::MedicationsControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @user = users(:one)
    @token = nil
    @medication = medications(:one)
  end

  def authenticated_token
    @token ||= login_user(@user.email, "password123")
  end

  # ===============
  # Index
  # ===============

  test "index returns all medications for user" do
    get "/api/v1/medications", headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_collection("medication")
    # User one has 2 medications
    assert_equal 2, json_response[:data].length
  end

  test "index fails without authentication" do
    get "/api/v1/medications", headers: api_headers

    assert_response :unauthorized
  end

  # ===============
  # Show
  # ===============

  test "show returns medication details" do
    get "/api/v1/medications/#{@medication.id}", headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_resource("medication", @medication.id)
    assert_equal "Ibuprofen", json_response[:data][:attributes][:name]
  end

  test "show fails for non-existent medication" do
    get "/api/v1/medications/999999", headers: api_headers(authenticated_token)

    assert_response :not_found
  end

  test "show fails for another user's medication" do
    other_medication = medications(:three) # belongs to user two

    get "/api/v1/medications/#{other_medication.id}", headers: api_headers(authenticated_token)

    assert_response :not_found
  end

  # ===============
  # Create
  # ===============

  test "create creates a new medication" do
    assert_difference("@user.medications.count", 1) do
      post "/api/v1/medications",
        params: { name: "Sumatriptan" }.to_json,
        headers: api_headers(authenticated_token)
    end

    assert_response :created
    assert_json_api_resource("medication")
    assert_equal "Sumatriptan", json_response[:data][:attributes][:name]
  end

  test "create fails with empty name" do
    assert_no_difference("Medication.count") do
      post "/api/v1/medications",
        params: { name: "" }.to_json,
        headers: api_headers(authenticated_token)
    end

    assert_response :unprocessable_entity
    assert json_response[:errors].present?
  end

  test "create fails with duplicate name" do
    assert_no_difference("@user.medications.count") do
      post "/api/v1/medications",
        params: { name: @medication.name }.to_json,
        headers: api_headers(authenticated_token)
    end

    assert_response :unprocessable_entity
  end

  test "create fails without authentication" do
    post "/api/v1/medications",
      params: { name: "Sumatriptan" }.to_json,
      headers: api_headers

    assert_response :unauthorized
  end

  # ===============
  # Update
  # ===============

  test "update modifies medication name" do
    patch "/api/v1/medications/#{@medication.id}",
      params: { name: "Updated Ibuprofen" }.to_json,
      headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_resource("medication", @medication.id)
    assert_equal "Updated Ibuprofen", json_response[:data][:attributes][:name]
  end

  test "update fails for another user's medication" do
    other_medication = medications(:three)

    patch "/api/v1/medications/#{other_medication.id}",
      params: { name: "Hacked" }.to_json,
      headers: api_headers(authenticated_token)

    assert_response :not_found
  end

  # ===============
  # Destroy
  # ===============

  test "destroy deletes medication" do
    # Create a medication without migraines
    medication = @user.medications.create!(name: "To Delete")

    assert_difference("@user.medications.count", -1) do
      delete "/api/v1/medications/#{medication.id}", headers: api_headers(authenticated_token)
    end

    assert_response :no_content
  end

  test "destroy fails for another user's medication" do
    other_medication = medications(:three)

    assert_no_difference("Medication.count") do
      delete "/api/v1/medications/#{other_medication.id}", headers: api_headers(authenticated_token)
    end

    assert_response :not_found
  end
end
