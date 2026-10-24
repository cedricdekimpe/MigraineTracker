require "test_helper"

class MonthlyOverviewTest < ActiveSupport::TestCase
  setup do
    @user = User.create!({ email: "overview@example.com", password: "password123" }.merge(consent_attrs))
    @triptan = @user.medications.create!(name: "Sumatriptan", kind: "triptan")
    @acute = @user.medications.create!(name: "Ibuprofen", kind: "acute")
    @preventive = @user.medications.create!(name: "Propranolol", kind: "preventive")
    @today = Date.new(2026, 10, 23)
    # The tests fill the whole of October 2026, which must not be in the future
    travel_to Time.zone.local(2026, 10, 31, 12)
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

  # October 2026 days that keep within `per_week` treatment days in each Monday-to-Sunday week
  def calm_days(per_week, count)
    taken = Hash.new(0)
    (1..31).filter_map do |day|
      date = Date.new(2026, 10, day)
      next if taken[date.beginning_of_week] >= per_week

      taken[date.beginning_of_week] += 1
      date
    end.first(count)
  end

  test "triptans: ok, advised from 8 days a month, over from 10" do
    calm_days(2, 7).each { |date| episode(date, medications: [@triptan]) }
    assert_equal :ok, overview.current.overuse_status

    calm_days(2, 8).each { |date| episode(date, medications: [@triptan]) unless @user.episodes.exists?(occurred_on: date) }
    assert_equal :advised, overview.current.overuse_status

    calm_days(2, 10).each { |date| episode(date, medications: [@triptan]) unless @user.episodes.exists?(occurred_on: date) }
    assert_equal :over, overview.current.overuse_status
  end

  test "simple analgesics: advised from 10 days a month, over only from 15" do
    calm_days(3, 9).each { |date| episode(date, medications: [@acute]) }
    assert_equal :ok, overview.current.overuse_status

    calm_days(3, 10).each { |date| episode(date, medications: [@acute]) unless @user.episodes.exists?(occurred_on: date) }
    assert_equal :advised, overview.current.overuse_status

    calm_days(3, 15).each { |date| episode(date, medications: [@acute]) unless @user.episodes.exists?(occurred_on: date) }
    assert_equal 15, overview.current.acute_days
    assert_equal :over, overview.current.overuse_status
  end

  test "a heavy week is advised even when the month is light" do
    (5..8).each { |day| episode(Date.new(2026, 10, day), medications: [@acute]) } # four days in the week of the 5th
    assert_equal 1, overview.current.heavy_weeks
    assert_equal :advised, overview.current.overuse_status

    calm_week = Date.new(2026, 10, 12)
    [calm_week, calm_week + 1].each { |date| episode(date, medications: [@triptan]) }
    assert_equal 1, overview.current.heavy_weeks
  end

  test "three triptan days in a week is a heavy week, two is not" do
    [Date.new(2026, 10, 5), Date.new(2026, 10, 6)].each { |date| episode(date, medications: [@triptan]) }
    assert_equal 0, overview.current.heavy_weeks
    episode(Date.new(2026, 10, 7), medications: [@triptan])
    assert_equal 1, overview.current.heavy_weeks
  end

  test "a week belongs to the month of its Monday and counts all its seven days" do
    # Week of Monday 28 Sept 2026 runs into October: 3 days in September, 1 in October
    [Date.new(2026, 9, 29), Date.new(2026, 9, 30), Date.new(2026, 10, 1)].each { |date| episode(date, medications: [@triptan]) }
    assert_equal [1, 0], [overview.months[-2].heavy_weeks, overview.current.heavy_weeks]
  end

  test "the threshold three months in a row is sustained overuse" do
    [Date.new(2026, 8, 1), Date.new(2026, 9, 1), Date.new(2026, 10, 1)].each do |month|
      (0...10).each { |offset| episode(month + offset, medications: [@triptan]) }
    end
    assert_equal [1, 2, 3], overview.months.last(3).map(&:streak)
    assert_equal [:over, :over, :sustained], overview.months.last(3).map(&:overuse_status)
  end

  test "a month under the threshold breaks the streak" do
    [Date.new(2026, 8, 1), Date.new(2026, 10, 1)].each do |month|
      (0...10).each { |offset| episode(month + offset, medications: [@triptan]) }
    end
    assert_equal [1, 0, 1], overview.months.last(3).map(&:streak)
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

  test "combined analgesics and opioids trip their own threshold at 10 days" do
    combination = @user.medications.create!(name: "Paracetamol + codeine", kind: "combination")
    9.times { |i| episode(Date.new(2026, 10, i + 1), medications: [combination]) }
    assert_equal :advised, overview.current.overuse_status

    episode(Date.new(2026, 10, 10), medications: [combination])
    assert_equal :over, overview.current.overuse_status
    assert_equal 10, overview.current.combination_days
    assert_equal 0, overview.current.acute_days
  end

  test "gepants count in the mix and as treatment days but have no threshold of their own" do
    gepant = @user.medications.create!(name: "Rimegepant", kind: "gepant")
    9.times { |i| episode(Date.new(2026, 10, i + 1), medications: [gepant]) }
    assert_equal :ok, overview.current.overuse_status
    assert_equal [9, 9], [overview.current.gepant_days, overview.current.any_acute_days]

    episode(Date.new(2026, 10, 10), medications: [@acute])
    assert overview.current.mixed?
    assert_equal :over, overview.current.overuse_status
  end

  test "an anti-nausea drug is never counted" do
    antiemetic = @user.medications.create!(name: "Metoclopramide", kind: "other")
    15.times { |i| episode(Date.new(2026, 10, i + 1), medications: [antiemetic]) }
    assert_equal 0, overview.current.any_acute_days
    assert_equal :ok, overview.current.overuse_status
  end

  test "moderate-to-severe days start at 4 out of 10 and ignore auras" do
    @user.episodes.create!(occurred_on: Date.new(2026, 10, 1), pain_kind: "migraine", intensity: 3)
    @user.episodes.create!(occurred_on: Date.new(2026, 10, 2), pain_kind: "migraine", intensity: 4)
    @user.episodes.create!(occurred_on: Date.new(2026, 10, 3), pain_kind: "headache", intensity: 2)
    @user.episodes.create!(occurred_on: Date.new(2026, 10, 3), pain_kind: "headache", intensity: 6) # same day: one day
    @user.episodes.create!(occurred_on: Date.new(2026, 10, 4), aura: true)
    assert_equal [3, 2], [overview.current.pain_days, overview.current.severe_days]
  end

  test "chronic pattern needs 15 headache days with 8 migraine days, and counts the months in a row" do
    [Date.new(2026, 8, 1), Date.new(2026, 9, 1), Date.new(2026, 10, 1)].each do |month|
      8.times { |i| episode(month + i) }
      7.times { |i| episode(month + 8 + i, pain: "headache") }
    end
    assert overview.current.chronic_pattern?
    assert_equal 3, overview.chronic_streak

    @user.episodes.where(occurred_on: Date.new(2026, 9, 1)..Date.new(2026, 9, 30), pain_kind: "headache").destroy_all
    assert_equal 1, overview.chronic_streak
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
