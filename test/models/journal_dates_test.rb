require "test_helper"

class JournalDatesTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 10, 24)

  test "a month of the journal is read as its first day" do
    assert_equal Date.new(2024, 3, 1), JournalDates.month("2024-03", today: TODAY)
    assert_equal Date.new(1900, 1, 1), JournalDates.month("1900-01", today: TODAY)
    assert_equal Date.new(2026, 10, 1), JournalDates.month("2026-10", today: TODAY)
  end

  test "months that are malformed, too old or in the future are refused" do
    [ "1-01", "1" + "0" * 400 + "-01", "1899-12", "2026-11", "2024-13", "2024-3", "-2024-01", "", nil, [ "2024-01" ] ].each do |value|
      assert_nil JournalDates.month(value, today: TODAY), value.inspect
    end
  end

  test "a year of the journal is read, other years refused" do
    assert_equal 2024, JournalDates.year("2024", today: TODAY)
    assert_equal 1900, JournalDates.year("1900", today: TODAY)
    [ "1899", "2027", "99999", "1" + "0" * 400, "20x4", "", nil ].each do |value|
      assert_nil JournalDates.year(value, today: TODAY), value.inspect
    end
  end

  test "dates are covered from 1 January 1900 to today" do
    assert JournalDates.cover?(Date.new(1900, 1, 1), today: TODAY)
    assert JournalDates.cover?(TODAY, today: TODAY)
    assert_not JournalDates.cover?(Date.new(1899, 12, 31), today: TODAY)
    assert_not JournalDates.cover?(TODAY + 1, today: TODAY)
  end
end
