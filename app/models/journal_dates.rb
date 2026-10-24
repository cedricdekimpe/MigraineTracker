# frozen_string_literal: true

# The dates the journal accepts, from 1 January 1900 to today: nothing in the future, and nothing so
# old that it can only come from a typo or a hand-made URL (year 1, or a year with hundreds of digits).
module JournalDates
  EARLIEST = Date.new(1900, 1, 1)

  module_function

  def range(today: Date.current)
    EARLIEST..today
  end

  def cover?(date, today: Date.current)
    range(today: today).cover?(date)
  end

  # First day of the month written "YYYY-MM", or nil when it is malformed or outside the journal.
  def month(value, today: Date.current)
    return nil unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}\z/)

    first = Date.strptime(value, "%Y-%m")
    first if first.between?(EARLIEST, today.beginning_of_month)
  rescue Date::Error
    nil
  end

  # The year written "YYYY", or nil when it is malformed or outside the journal.
  def year(value, today: Date.current)
    return nil unless value.is_a?(String) && value.match?(/\A\d{4}\z/)

    year = value.to_i
    year if year.between?(EARLIEST.year, today.year)
  end
end
