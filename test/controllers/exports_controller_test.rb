require "test_helper"

class ExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "should require authentication" do
    sign_out @user
    post exports_path
    assert_redirected_to new_user_session_path
  end

  test "should export user data as JSON" do
    post exports_path
    assert_response :success
    assert_equal "application/json", response.content_type
  end

  test "should set attachment disposition" do
    post exports_path
    assert_response :success
    assert_match /attachment/, response.headers["Content-Disposition"]
  end

  test "should include filename with user id and timestamp" do
    post exports_path
    assert_response :success
    assert_match /migraine_data_#{@user.id}_\d{8}_\d{6}\.json/, response.headers["Content-Disposition"]
  end

  test "exported JSON should contain user email" do
    post exports_path
    assert_response :success
    
    data = JSON.parse(response.body)
    assert_equal @user.email, data["user_email"]
  end

  test "exported JSON should contain exported_at timestamp" do
    post exports_path
    assert_response :success
    
    data = JSON.parse(response.body)
    assert_not_nil data["exported_at"]
    assert_nothing_raised { Time.iso8601(data["exported_at"]) }
  end

  test "should export all user medications" do
    # Create test medications
    med1 = @user.medications.create!(name: "Aspirin")
    med2 = @user.medications.create!(name: "Ibuprofen")
    
    post exports_path
    assert_response :success
    
    data = JSON.parse(response.body)
    assert_equal 2, data["medications"].length
    
    medication_names = data["medications"].map { |m| m["name"] }
    assert_includes medication_names, "Aspirin"
    assert_includes medication_names, "Ibuprofen"
  end

  test "should export all user migraines with medication names" do
    # Create test data
    medication = @user.medications.create!(name: "Test Med")
    migraine = @user.migraines.create!(
      occurred_on: Date.today,
      nature: "strong",
      intensity: 8,
      on_period: false,
      medication: medication
    )
    
    post exports_path
    assert_response :success
    
    data = JSON.parse(response.body)
    assert_equal 1, data["migraines"].length
    
    exported_migraine = data["migraines"].first
    assert_equal Date.today.to_s, exported_migraine["occurred_on"]
    assert_equal "strong", exported_migraine["nature"]
    assert_equal 8, exported_migraine["intensity"]
    assert_equal false, exported_migraine["on_period"]
    assert_equal "Test Med", exported_migraine["medication_name"]
  end

  test "should handle migraine without medication" do
    @user.migraines.create!(
      occurred_on: Date.today,
      nature: "weak",
      intensity: 3,
      on_period: true
    )
    
    post exports_path
    assert_response :success
    
    data = JSON.parse(response.body)
    exported_migraine = data["migraines"].first
    assert_nil exported_migraine["medication_name"]
  end

  test "should only export current user's data" do
    other_user = User.create!(
      email: "other@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    other_user.medications.create!(name: "Other Med")
    other_user.migraines.create!(
      occurred_on: Date.today,
      nature: "strong",
      intensity: 7,
      on_period: false
    )
    
    post exports_path
    assert_response :success
    
    data = JSON.parse(response.body)
    assert_equal @user.email, data["user_email"]
    assert_equal 0, data["medications"].length
    assert_equal 0, data["migraines"].length
  end
end
