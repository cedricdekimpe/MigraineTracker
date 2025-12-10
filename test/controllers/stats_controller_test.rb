require "test_helper"

class StatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "should get index" do
    get stats_url
    assert_response :success
  end

  test "should calculate total migraines" do
    get stats_url
    assert_not_nil assigns(:total_migraines)
    assert_equal @user.migraines.count, assigns(:total_migraines)
  end

  test "should calculate migraines with and without medication" do
    get stats_url
    assert_not_nil assigns(:migraines_with_medication)
    assert_not_nil assigns(:migraines_without_medication)
    
    with_med = @user.migraines.where.not(medication_id: nil).count
    without_med = @user.migraines.where(medication_id: nil).count
    
    assert_equal with_med, assigns(:migraines_with_medication)
    assert_equal without_med, assigns(:migraines_without_medication)
  end

  test "should generate monthly data for last 12 months" do
    get stats_url
    assert_not_nil assigns(:monthly_data)
    assert_equal 12, assigns(:monthly_data).length
    
    # Each entry should be [month_string, count]
    assigns(:monthly_data).each do |entry|
      assert_equal 2, entry.length
      assert_kind_of String, entry[0]
      assert_kind_of Integer, entry[1]
    end
  end

  test "should generate day of week distribution" do
    get stats_url
    assert_not_nil assigns(:day_of_week_data)
    
    # Should have entries for days that have migraines
    assigns(:day_of_week_data).each do |day, count|
      assert_kind_of String, day
      assert_kind_of Integer, count
      assert_includes Date::DAYNAMES, day
    end
  end

  test "should generate medication data" do
    get stats_url
    assert_not_nil assigns(:medication_data)
    
    # Each entry should be [medication_name, count]
    assigns(:medication_data).each do |entry|
      assert_equal 2, entry.length
      assert_kind_of String, entry[0]
      assert_kind_of Integer, entry[1]
    end
  end

  test "should require authentication" do
    sign_out @user
    get stats_url
    assert_redirected_to new_user_session_url
  end

  test "should only show current user migraines" do
    other_user = User.create!(email: "other@example.com", password: "password123")
    other_migraine = other_user.migraines.create!(
      occurred_on: Date.today,
      intensity: 3,
      nature: "M",
      on_period: false
    )
    
    get stats_url
    
    # Should not include other user's migraines in any stats
    assert_equal @user.migraines.count, assigns(:total_migraines)
  end
end
