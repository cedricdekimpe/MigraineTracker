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

  test "monthly data covers 12 months including the current one and matches logged episodes" do
    get stats_url
    monthly_data = stats_data_attribute("monthly")
    assert_equal 12, monthly_data.length
    assert_equal Date.current.strftime("%b %Y"), monthly_data.last.first
    assert_equal @user.episodes.where(occurred_on: 11.months.ago.beginning_of_month..Date.current.end_of_month).count,
                 monthly_data.sum { |entry| entry[1] }
  end

  test "day-of-week breakdown lists all seven weekdays with zeros" do
    get stats_url
    day_data = stats_data_attribute("day-of-week")
    assert_equal 7, day_data.length

    expected_counts = Hash.new(0)
    @user.episodes.each { |episode| expected_counts[Date::DAYNAMES[episode.occurred_on.wday]] += 1 }

    day_data.each { |day, count| assert_equal expected_counts[day], count }
    assert_equal @user.episodes.count, day_data.sum { |_, count| count }
  end

  test "medication breakdown counts intakes per medication" do
    get stats_url
    medication_data = stats_data_attribute("medication").to_h

    assert_equal 2, medication_data["Ibuprofen"]
    assert_equal 1, medication_data["Paracetamol"]
    assert_not_includes medication_data, "Aspirin"
  end

  test "summary counts episodes with and without medication" do
    get stats_url

    with_medication = @user.episodes.joins(:medication_intakes).distinct.count
    assert_select "p", text: with_medication.to_s
    assert_equal 2, with_medication
  end

  test "triggers section shows how often each trigger was ticked" do
    get stats_url

    assert_select "[data-triggers] li", text: /Stress.*1 of #{@user.episodes.count} episodes/m
    assert_select "[data-triggers] li", text: /Lack of sleep/
  end

  test "triggers section has an empty state" do
    EpisodeTrigger.delete_all
    get stats_url
    assert_select "[data-triggers] li", count: 0
    assert_select "[data-triggers]", text: /No triggers ticked yet/
  end

  test "only the user's own data is counted" do
    sign_in users(:two)
    get stats_url

    assert_equal 1, stats_data_attribute("day-of-week").sum { |_, count| count }
    assert_equal [], stats_data_attribute("medication")
  end

  private

  def stats_data_attribute(attribute_name)
    element = css_select("[data-#{attribute_name}]").first
    return [] unless element
    JSON.parse(element["data-#{attribute_name}"])
  end
end
