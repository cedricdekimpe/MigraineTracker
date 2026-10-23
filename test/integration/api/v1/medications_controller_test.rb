# frozen_string_literal: true

require "test_helper"

class Api::V1::MedicationsControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @user = users(:one)
    @token = nil
    @medication = medications(:ibuprofen)
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
    # Active medications only (the archived one is hidden)
    assert_equal 3, json_response[:data].length
    assert_not_includes json_response[:data].map { |m| m[:attributes][:name] }, "Old Med"
  end

  test "index can include archived medications" do
    get "/api/v1/medications", params: { include_archived: "true" }, headers: api_headers(authenticated_token)

    assert_equal 4, json_response[:data].length
    old = json_response[:data].find { |m| m[:attributes][:name] == "Old Med" }
    assert_equal true, old[:attributes][:archived]
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
    other_medication = medications(:aspirin) # belongs to user two

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
    other_medication = medications(:aspirin)

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

  test "destroy archives a medication that has history" do
    assert_no_difference("MedicationIntake.count") do
      delete "/api/v1/medications/#{@medication.id}", headers: api_headers(authenticated_token)
    end

    assert_response :no_content
    assert @medication.reload.archived?
  end

  test "create accepts kind and default dose" do
    post "/api/v1/medications",
      params: { name: "Rizatriptan", kind: "acute", default_dose: "10 mg" }.to_json,
      headers: api_headers(authenticated_token)

    assert_response :created
    attrs = json_response[:data][:attributes]
    assert_equal ["acute", "10 mg"], [attrs[:kind], attrs[:default_dose]]
  end

  test "create rejects an unknown kind" do
    post "/api/v1/medications",
      params: { name: "Mystery", kind: "magic" }.to_json,
      headers: api_headers(authenticated_token)

    assert_response :unprocessable_entity
  end

  test "destroy fails for another user's medication" do
    other_medication = medications(:aspirin)

    assert_no_difference("Medication.count") do
      delete "/api/v1/medications/#{other_medication.id}", headers: api_headers(authenticated_token)
    end

    assert_response :not_found
  end
end
