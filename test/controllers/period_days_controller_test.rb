require "test_helper"

class PeriodDaysControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @user.update!(track_cycle: true)
    sign_in @user
    @date = Date.current - 2.days
  end

  test "marks a day, once" do
    assert_difference -> { @user.period_days.count }, 1 do
      post period_days_path, params: { date: @date.iso8601 }
      post period_days_path, params: { date: @date.iso8601 }
    end
    assert_redirected_to episodes_path(month: @date.strftime("%Y-%m"))
  end

  test "unmarks a day" do
    @user.period_days.create!(date: @date)
    assert_difference -> { @user.period_days.count }, -1 do
      delete period_day_path(date: @date.iso8601)
    end
  end

  test "future days and bad dates are refused" do
    assert_no_difference -> { PeriodDay.count } do
      post period_days_path, params: { date: (Date.current + 1).iso8601 }
      assert_response :unprocessable_entity
      post period_days_path, params: { date: "2026-02-30" }
      assert_response :bad_request
    end
  end

  test "does nothing without cycle tracking" do
    @user.update!(track_cycle: false)
    assert_no_difference -> { PeriodDay.count } do
      post period_days_path, params: { date: @date.iso8601 }
    end
    assert_redirected_to episodes_path
  end

  test "only touches the signed-in user's days" do
    other = users(:two)
    other.period_days.create!(date: @date)
    delete period_day_path(date: @date.iso8601)
    assert other.period_days.exists?(date: @date)
  end

  test "requires authentication" do
    sign_out @user
    post period_days_path, params: { date: @date.iso8601 }
    assert_redirected_to new_user_session_path
  end

  test "the wide sheet offers the tap on each past day; the phone list only shows the marked days" do
    @user.period_days.create!(date: @date)
    get episodes_path
    assert_select "table td[data-attribute=cycle] button", minimum: 1
    assert_select "li[data-date='#{@date.iso8601}'] form", count: 0
    assert_select "li[data-date='#{@date.iso8601}'] [data-attribute=cycle]", text: "0"
  end
end
