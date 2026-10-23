require "test_helper"

class DailyFactorsTest < ActiveSupport::TestCase
  setup do
    @user = User.create!({ email: "factors@example.com", password: "password123" }.merge(consent_attrs))
    @today = Date.new(2026, 10, 23)
    @start = Date.new(2026, 8, 1)
  end

  def factors
    DailyFactors.new(@user, today: @today)
  end

  def check(offset, **answers)
    @user.daily_checks.create!(date: @start + offset, **answers)
  end

  def pain(offset)
    @user.episodes.create!(occurred_on: @start + offset, pain_kind: "migraine", intensity: 5)
  end

  test "says nothing before 30 days of check-ins" do
    29.times { |i| check(i, sleep: "short") }
    assert_not factors.enough_data?
    assert_empty factors.results
    assert_empty factors.notable
  end

  test "compares the pain days after a bad night with the other days, for each delay" do
    60.times do |i|
      bad = i % 3 == 0
      check(i, sleep: bad ? "fragmented" : "good")
      pain(i + 2) if bad # an attack two days after every bad night
    end

    result = factors.results.find { |row| row.factor == :poor_sleep && row.lag == 2 }
    assert_equal [20, 20, 40], [result.exposed_days, result.exposed_pain_days, result.other_days]
    assert_equal [100, 0, 100], [result.exposed_share, result.other_share, result.gap]
    assert result.notable?
    assert_equal :poor_sleep, factors.notable.first.factor
    same_day = factors.results.find { |row| row.factor == :poor_sleep && row.lag == 0 }
    assert_not same_day.notable?
  end

  test "a small gap or too few exposed days is not notable" do
    40.times do |i|
      bad = i < 5 # only 5 exposed days
      check(i, caffeine: bad ? "high" : "usual")
      pain(i) if bad
    end
    result = factors.results.find { |row| row.factor == :caffeine_high && row.lag == 0 }
    assert_equal 5, result.exposed_days
    assert_not result.notable?
  end

  test "days without an answer are left out of both groups" do
    35.times { |i| check(i, sleep: i.even? ? "short" : nil, stress: "low") }
    result = factors.results.find { |row| row.factor == :poor_sleep && row.lag == 0 }
    assert_nil result # nothing to compare with: no day with a good night
  end

  test "a drop in stress is compared with the day before" do
    40.times { |i| check(i, stress: i % 4 == 3 ? "low" : "high") }
    result = factors.results.find { |row| row.factor == :stress_drop && row.lag == 0 }
    assert_equal 10, result.exposed_days
  end

  test "delays reaching beyond today are not counted" do
    @today = @start + 34
    35.times { |i| check(i, sleep: i.even? ? "short" : "good") }
    last = factors.results.find { |row| row.factor == :poor_sleep && row.lag == 2 }
    assert_equal 33, last.exposed_days + last.other_days # the last two check-ins have no outcome day yet
  end

  test "other users' days are never used" do
    35.times { |i| users(:two).daily_checks.create!(date: @start + i, sleep: "short") }
    assert_equal 0, factors.checked_days
  end
end
