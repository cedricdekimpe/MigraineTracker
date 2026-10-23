require "test_helper"

class TreatmentPeriodTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @medication = medications(:candesartan)
  end

  def build(attributes = {})
    @medication.treatment_periods.new({ user: @user, started_on: Date.new(2026, 1, 1) }.merge(attributes))
  end

  test "an open-ended period is current" do
    period = build
    assert period.valid?
    assert period.current?
  end

  test "only a preventive of the same user can have periods" do
    assert_not TreatmentPeriod.new(user: @user, medication: medications(:ibuprofen), started_on: Date.new(2026, 1, 1)).valid?
    assert_not TreatmentPeriod.new(user: @user, medication: medications(:aspirin), started_on: Date.new(2026, 1, 1)).valid?
  end

  test "the end cannot precede the start" do
    assert_not build(ended_on: Date.new(2025, 12, 31)).valid?
    assert build(ended_on: Date.new(2026, 1, 1)).valid?
  end

  test "a reason for stopping needs an end date and a known value" do
    assert_not build(stop_reason: "ineffective").valid?
    assert build(ended_on: Date.new(2026, 4, 1), stop_reason: "not_tolerated").valid?
    assert_not build(ended_on: Date.new(2026, 4, 1), stop_reason: "boredom").valid?
  end

  test "periods of the same medication cannot overlap" do
    build(ended_on: Date.new(2026, 3, 31)).save!
    assert_not build(started_on: Date.new(2026, 3, 31)).valid?
    assert_not build(started_on: Date.new(2025, 12, 1), ended_on: Date.new(2026, 1, 5)).valid?
    assert build(started_on: Date.new(2026, 4, 1)).valid?
  end

  test "an open period blocks any later start" do
    build.save!
    assert_not build(started_on: Date.new(2027, 1, 1)).valid?
  end

  test "counts whole days, up to today while it goes on" do
    assert_equal 90, build(started_on: Date.new(2026, 1, 1), ended_on: Date.new(2026, 3, 31)).days
    assert_equal 10, build(started_on: Date.new(2026, 10, 14)).days(today: Date.new(2026, 10, 23))
  end

  test "a medication with periods is archived, not deleted" do
    build.save!
    @medication.retire!
    assert @medication.reload.archived?
  end

  test "the database refuses an end before the start" do
    assert_raises(ActiveRecord::StatementInvalid) do
      TreatmentPeriod.new(user: @user, medication: @medication, started_on: Date.new(2026, 2, 1), ended_on: Date.new(2026, 1, 1)).save!(validate: false)
    end
  end
end
