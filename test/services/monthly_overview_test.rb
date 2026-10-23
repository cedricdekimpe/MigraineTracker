require "test_helper"

class MonthlyOverviewTest < ActiveSupport::TestCase
  setup do
    @user = User.create!({ email: "overview@example.com", password: "password123" }.merge(consent_attrs))
    @triptan = @user.medications.create!(name: "Sumatriptan", kind: "triptan")
    @acute = @user.medications.create!(name: "Ibuprofen", kind: "acute")
    @preventive = @user.medications.create!(name: "Propranolol", kind: "preventive")
    @today = Date.new(2026, 10, 23)
  end

  def episode(date, pain: "migraine", aura: false, medications: [])
    episode = @user.episodes.create!(occurred_on: date, pain_kind: pain, aura: aura, intensity: pain ? 5 : nil)
    medications.each { |medication| episode.medication_intakes.create!(medication: medication) }
    episode
  end

  def overview(**options)
    MonthlyOverview.new(@user, today: @today, **options)
  end

  test "covers the requested number of months ending with the current one" do
    months = overview.months

    assert_equal 12, months.size
    assert_equal Date.new(2025, 11, 1), months.first.month
    assert_equal Date.new(2026, 10, 1), overview.current.month
    assert_equal 3, overview(months: 3).months.size
  end

  test "counts days, not episodes" do
    episode(Date.new(2026, 10, 5))
    episode(Date.new(2026, 10, 5)) # second migraine the same day
    episode(Date.new(2026, 10, 6), pain: "headache")

    current = overview.current
    assert_equal [1, 1, 2], [current.migraine_days, current.headache_days, current.pain_days]
  end

  test "a day with a migraine and a headache is a migraine day only" do
    episode(Date.new(2026, 10, 7), pain: "headache")
    episode(Date.new(2026, 10, 7), pain: "migraine")

    current = overview.current
    assert_equal [1, 0], [current.migraine_days, current.headache_days]
  end

  test "aura without pain is counted apart, and an aura before a migraine is not an aura day" do
    episode(Date.new(2026, 10, 8), pain: nil, aura: true)
    episode(Date.new(2026, 10, 9), pain: "migraine", aura: true)

    current = overview.current
    assert_equal [1, 1, 1], [current.aura_days, current.migraine_days, current.pain_days]
  end

  test "counts triptan and other acute days, once per day, ignoring preventive treatments" do
    episode(Date.new(2026, 10, 10), medications: [@triptan, @triptan, @acute])
    episode(Date.new(2026, 10, 11), medications: [@acute, @preventive])
    episode(Date.new(2026, 10, 12), medications: [@preventive])

    current = overview.current
    assert_equal [1, 2, 2], [current.triptan_days, current.acute_days, current.any_acute_days]
  end

  test "months are separated and old data outside the window is ignored" do
    episode(Date.new(2026, 9, 30))
    episode(Date.new(2026, 10, 1))
    episode(Date.new(2024, 1, 1))

    months = overview.months
    assert_equal 1, months.find { |m| m.month == Date.new(2026, 9, 1) }.migraine_days
    assert_equal 1, overview.current.migraine_days
    assert_equal 2, months.sum(&:migraine_days)
  end

  test "overuse is ok, watch, then over for triptans at 10 days a month" do
    (1..7).each { |day| episode(Date.new(2026, 10, day), medications: [@triptan]) }
    assert_equal :ok, overview.current.overuse_status

    episode(Date.new(2026, 10, 8), medications: [@triptan])
    assert_equal :watch, overview.current.overuse_status

    episode(Date.new(2026, 10, 9), medications: [@triptan])
    episode(Date.new(2026, 10, 10), medications: [@triptan])
    assert_equal :over, overview.current.overuse_status
  end

  test "other acute treatments only trip the 15 day threshold" do
    (1..10).each { |day| episode(Date.new(2026, 10, day), medications: [@acute]) }
    assert_equal :ok, overview.current.overuse_status

    (11..12).each { |day| episode(Date.new(2026, 10, day), medications: [@acute]) }
    assert_equal :watch, overview.current.overuse_status

    (13..15).each { |day| episode(Date.new(2026, 10, day), medications: [@acute]) }
    assert_equal :over, overview.current.overuse_status
  end

  test "mixing both kinds trips the combined threshold of 10 days" do
    (1..5).each { |day| episode(Date.new(2026, 10, day), medications: [@triptan]) }
    (6..10).each { |day| episode(Date.new(2026, 10, day), medications: [@acute]) }

    current = overview.current
    assert current.mixed?
    assert_equal [5, 5, 10], [current.triptan_days, current.acute_days, current.any_acute_days]
    assert_equal :over, current.overuse_status
  end

  test "average of the last complete months excludes the current month" do
    episode(Date.new(2026, 10, 1)) # current month, ignored
    [Date.new(2026, 7, 1), Date.new(2026, 8, 1), Date.new(2026, 8, 2), Date.new(2026, 9, 1), Date.new(2026, 9, 2), Date.new(2026, 9, 3)].each { |date| episode(date) }

    assert_in_delta 2.0, overview.average_pain_days(3), 0.01
  end

  test "no average without a complete month" do
    assert_nil MonthlyOverview.new(@user, months: 1, today: @today).average_pain_days

    episode(Date.new(2026, 10, 1)) # only the current month has data
    assert_nil overview.average_pain_days
  end

  test "months before the first record do not drag the average down" do
    [Date.new(2026, 8, 1), Date.new(2026, 8, 2), Date.new(2026, 9, 1), Date.new(2026, 9, 2)].each { |date| episode(date) }

    assert_in_delta 2.0, overview.average_pain_days(3), 0.01 # Aug and Sep only, not 9 empty months
  end

  test "an empty account gives zeros" do
    empty = MonthlyOverview.new(User.create!({ email: "blank@example.com", password: "password123" }.merge(consent_attrs)), today: @today)

    assert_equal 0, empty.months.sum(&:pain_days)
    assert_equal :ok, empty.current.overuse_status
  end

  test "other users' data is never counted" do
    users(:two).episodes.create!(occurred_on: Date.new(2026, 10, 5), pain_kind: "migraine", intensity: 5)
    assert_equal 0, overview.current.migraine_days
  end
end
