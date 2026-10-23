require "test_helper"

class DailyCheckTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  test "every answer is optional" do
    assert @user.daily_checks.new(date: Date.current).valid?
  end

  test "answers must be known values" do
    assert_not @user.daily_checks.new(date: Date.current, sleep: "great").valid?
    assert_not @user.daily_checks.new(date: Date.current, stress: "huge").valid?
    assert_not @user.daily_checks.new(date: Date.current, caffeine: "lots").valid?
  end

  test "one check-in per day and per user" do
    @user.daily_checks.create!(date: Date.current)
    assert_not @user.daily_checks.new(date: Date.current).valid?
    assert users(:two).daily_checks.new(date: Date.current).valid?
  end

  test "not in the future" do
    assert_not @user.daily_checks.new(date: Date.current + 1).valid?
  end

  test "blank answers become nil, and stress can be compared" do
    check = @user.daily_checks.create!(date: Date.current, sleep: "", stress: "high")
    assert_nil check.sleep
    assert_equal 2, check.stress_level
    assert_nil @user.daily_checks.new(date: Date.current - 1).stress_level
  end
end
