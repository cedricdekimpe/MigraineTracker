# frozen_string_literal: true

# validates :occurred_on, journal_date: true
# Keeps a date within JournalDates: not in the future, not before 1900. A nil date is left to presence.
class JournalDateValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.nil?

    if value > Date.current
      record.errors.add(attribute, :future)
    elsif value < JournalDates::EARLIEST
      record.errors.add(attribute, :too_early, date: I18n.l(JournalDates::EARLIEST, format: :long))
    end
  end
end
