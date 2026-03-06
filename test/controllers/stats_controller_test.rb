require "test_helper"

class StatsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
  end

  test "should get index" do
    get stats_url
    assert_response :success
  end

  test "monthly data matches logged migraines" do
    get stats_url
    monthly_data = stats_data_attribute("monthly")
    assert_equal 12, monthly_data.length
    assert_equal @user.migraines.count, monthly_data.sum { |entry| entry[1] }
  end

  test "day-of-week breakdown lists weekdays" do
    get stats_url
    day_data = stats_data_attribute("day-of-week")
    assert_equal 7, day_data.length

    expected_counts = Hash.new(0)
    @user.migraines.each do |migraine|
      expected_counts[Date::DAYNAMES[migraine.occurred_on.wday]] += 1
    end

    day_data.each do |day, count|
      assert_equal expected_counts[day], count
    end
  end

  test "medication breakdown reflects current usage" do
    get stats_url
    medication_data = stats_data_attribute("medication")
    medication_counts = @user.migraines.where.not(medication_id: nil).joins(:medication).group("medications.name").count

    medication_data.each do |name, count|
      assert_equal medication_counts[name], count
    end
  end

  private

  def stats_data_attribute(attribute_name)
    element = css_select("[data-#{attribute_name}]").first
    return [] unless element
    JSON.parse(element["data-#{attribute_name}"])
  end
end
