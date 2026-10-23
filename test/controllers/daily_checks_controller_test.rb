require "test_helper"

class DailyChecksControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
    @today = Date.current
  end

  test "requires authentication" do
    sign_out @user
    get check_path
    assert_redirected_to new_user_session_path
  end

  test "the short path opens today's check-in" do
    get check_path
    assert_redirected_to daily_check_path(date: @today.iso8601)
  end

  test "the form asks the three questions" do
    get daily_check_path(date: @today.iso8601)
    assert_response :success
    assert_select "fieldset[data-question=sleep] input[type=radio]", 3
    assert_select "fieldset[data-question=stress] input[type=radio]", 3
    assert_select "fieldset[data-question=caffeine] input[type=radio]", 3
    assert_select "input[type=checkbox][name='daily_check[skipped_meal]']"
  end

  test "saves the answers for the day, and updates them" do
    assert_difference -> { @user.daily_checks.count }, 1 do
      patch daily_check_path(date: @today.iso8601), params: { daily_check: { sleep: "fragmented", stress: "high", skipped_meal: "1", caffeine: "usual" } }
    end
    check = @user.daily_checks.find_by!(date: @today)
    assert_equal ["fragmented", "high", true, "usual"], [check.sleep, check.stress, check.skipped_meal, check.caffeine]
    assert_redirected_to episodes_path(month: @today.strftime("%Y-%m"))

    assert_no_difference -> { @user.daily_checks.count } do
      patch daily_check_path(date: @today.iso8601), params: { daily_check: { sleep: "good", skipped_meal: "0" } }
    end
    assert_equal ["good", false], [check.reload.sleep, check.skipped_meal]
  end

  test "yesterday can be filled in, the future and old history cannot" do
    patch daily_check_path(date: (@today - 1).iso8601), params: { daily_check: { sleep: "short" } }
    assert @user.daily_checks.exists?(date: @today - 1)

    patch daily_check_path(date: (@today + 1).iso8601), params: { daily_check: { sleep: "short" } }
    assert_response :unprocessable_entity
    get daily_check_path(date: (@today - 2.years).iso8601)
    assert_response :unprocessable_entity
    get daily_check_path(date: "2026-02-30")
    assert_response :bad_request
  end

  test "an unknown answer is refused" do
    patch daily_check_path(date: @today.iso8601), params: { daily_check: { sleep: "wonderful" } }
    assert_redirected_to daily_check_path(date: @today.iso8601)
    assert_not @user.daily_checks.exists?(date: @today)
  end

  test "another user's check-in is never shown or changed" do
    users(:two).daily_checks.create!(date: @today, sleep: "short")
    get daily_check_path(date: @today.iso8601)
    assert_select "input[type=radio][checked]", 0
    patch daily_check_path(date: @today.iso8601), params: { daily_check: { sleep: "good" } }
    assert_equal "short", users(:two).daily_checks.find_by!(date: @today).sleep
  end

  test "the journal invites to today's check-in, then shows it done" do
    get episodes_path
    assert_select "a[data-daily-check-card=todo]"

    @user.daily_checks.create!(date: @today, sleep: "good")
    get episodes_path
    assert_select "a[data-daily-check-card=done]"
  end

  test "with cycle tracking, the check-in also asks about the period and records the day" do
    get daily_check_path(date: @today.iso8601)
    assert_select "fieldset[data-question=period]", count: 0

    @user.update!(track_cycle: true)
    get daily_check_path(date: @today.iso8601)
    assert_select "fieldset[data-question=period] input[type=radio][name=period]", 2

    patch daily_check_path(date: @today.iso8601), params: { daily_check: { sleep: "good" }, period: "yes" }
    assert @user.period_days.exists?(date: @today)

    get daily_check_path(date: @today.iso8601)
    assert_select "input[name=period][value=yes][checked]"

    patch daily_check_path(date: @today.iso8601), params: { daily_check: { sleep: "good" }, period: "no" }
    assert_not @user.period_days.exists?(date: @today)
  end

  test "an unanswered period question changes nothing" do
    @user.update!(track_cycle: true)
    @user.period_days.create!(date: @today)
    patch daily_check_path(date: @today.iso8601), params: { daily_check: { sleep: "good" } }
    assert @user.period_days.exists?(date: @today)
  end
end
