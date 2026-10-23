require "test_helper"

class SheetTest < ActiveSupport::TestCase
  setup do
    @user = User.create!({ email: "sheet@example.com", password: "password123" }.merge(consent_attrs))
    @triptan = @user.medications.create!(name: "Sumatriptan", kind: "triptan")
    @acute = @user.medications.create!(name: "Ibuprofen", kind: "acute")
    @preventive = @user.medications.create!(name: "Propranolol", kind: "preventive")
    @month = Date.new(2026, 10, 1)
  end

  def episode(day, pain: "migraine", aura: false, intensity: 5, on_period: false, medications: [])
    record = @user.episodes.create!(occurred_on: @month + (day - 1), pain_kind: pain, aura: aura, intensity: pain ? intensity : nil, on_period: on_period)
    medications.each { |medication| record.medication_intakes.create!(medication: medication) }
    record
  end

  def sheet
    Sheet.new(@user, months: [@month])
  end

  def day(number)
    sheet.day(@month + (number - 1))
  end

  test "an empty day has nothing" do
    empty = day(1)
    assert_not empty.any?
    assert_nil empty.letter
    assert_nil empty.intensity
    assert_not empty.treatment?
  end

  test "M for a migraine, T for another headache, A for an aura alone" do
    episode(2)
    episode(3, pain: "headache")
    episode(4, pain: nil, aura: true)

    assert_equal %w[M T A], [day(2).letter, day(3).letter, day(4).letter]
    assert_equal [true, true, false], [day(2).pain?, day(3).pain?, day(4).pain?]
  end

  test "a migraine wins over a headache the same day and the intensity is the strongest" do
    episode(5, pain: "headache", intensity: 8)
    episode(5, pain: "migraine", intensity: 6)

    assert_equal "M", day(5).letter
    assert_equal 8, day(5).intensity
    assert_equal 2, day(5).episodes.size
  end

  test "an aura with pain keeps the pain letter and is flagged" do
    episode(6, aura: true)
    assert_equal "M", day(6).letter
    assert day(6).aura_with_pain?

    episode(7, pain: nil, aura: true)
    assert_not day(7).aura_with_pain?
  end

  test "cycle is shown if any episode of the day is on a period" do
    episode(8, on_period: false)
    episode(8, on_period: true)
    assert day(8).cycle?
    assert_not day(1).cycle?
  end

  test "X for an acute treatment and t for a triptan, preventives are ignored" do
    episode(9, medications: [@acute])
    episode(10, medications: [@triptan])
    episode(11, medications: [@acute, @triptan])
    episode(12, medications: [@preventive])

    assert_equal [true, false], [day(9).acute?, day(9).triptan?]
    assert_equal [false, true], [day(10).acute?, day(10).triptan?]
    assert_equal [true, true], [day(11).acute?, day(11).triptan?]
    assert_not day(12).treatment?
  end

  test "X also covers combined analgesics and gepants, an anti-nausea drug shows nothing" do
    episode(13, medications: [@user.medications.create!(name: "Paracetamol + codeine", kind: "combination")])
    episode(14, medications: [@user.medications.create!(name: "Rimegepant", kind: "gepant")])
    episode(15, medications: [@user.medications.create!(name: "Metoclopramide", kind: "other")])

    assert day(13).acute?
    assert day(14).acute?
    assert_not day(15).treatment?
  end

  test "counts pain days and treatment days of a month" do
    episode(1, medications: [@acute])
    episode(2, pain: "headache")
    episode(3, pain: nil, aura: true)

    assert_equal 2, sheet.pain_days(@month)
    assert_equal 1, sheet.treatment_days(@month)
  end

  test "days_of covers every day of the month" do
    assert_equal 31, sheet.days_of(@month).size
    assert_equal 28, Sheet.new(@user, months: [Date.new(2027, 2, 1)]).days_of(Date.new(2027, 2, 1)).size
  end

  test "the quarter of a month follows the paper sheet: Jan-Mar, Apr-Jun, Jul-Sep, Oct-Dec" do
    assert_equal [Date.new(2026, 10, 1), Date.new(2026, 11, 1), Date.new(2026, 12, 1)], Sheet.quarter_of(Date.new(2026, 11, 15))
    assert_equal [Date.new(2026, 1, 1), Date.new(2026, 2, 1), Date.new(2026, 3, 1)], Sheet.quarter_of(Date.new(2026, 3, 31))
    assert_equal Date.new(2026, 7, 1), Sheet.quarter_of(Date.new(2026, 8, 3)).first
  end

  test "loads several months and never other users' data" do
    users(:two).episodes.create!(occurred_on: @month, pain_kind: "migraine", intensity: 5)
    episode(1)
    multi = Sheet.new(@user, months: Sheet.quarter_of(@month))

    assert_equal 1, multi.day(@month).episodes.size
    assert_equal 0, multi.day(Date.new(2026, 12, 31)).episodes.size
  end
end
