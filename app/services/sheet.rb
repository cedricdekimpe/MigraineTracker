# frozen_string_literal: true

# The paper calendar as data: one cell per day. A day shows (as on the sheet) a letter - M for a
# migraine, T for another headache - the strongest intensity, a cycle mark, and the treatment taken:
# X for an acute treatment, t for a triptan. Episodes are the detail behind a day.
class Sheet
  class Day
    attr_reader :date, :episodes

    def initialize(date, episodes)
      @date = date
      @episodes = episodes
    end

    def any?
      episodes.any?
    end

    # M beats T when both happen the same day (the day's detail lists every episode).
    def letter
      return "M" if episodes.any? { |episode| episode.pain_kind == "migraine" }
      return "T" if episodes.any? { |episode| episode.pain_kind == "headache" }

      "A" if episodes.any?(&:aura?)
    end

    # An aura that came with pain is shown as a small mark next to the letter.
    def aura_with_pain?
      letter.in?(%w[M T]) && episodes.any?(&:aura?)
    end

    def pain?
      letter.in?(%w[M T])
    end

    def intensity
      episodes.filter_map(&:intensity).max
    end

    def cycle?
      episodes.any?(&:on_period?)
    end

    def triptan?
      kinds.include?("triptan")
    end

    def acute?
      kinds.include?("acute")
    end

    def treatment?
      triptan? || acute?
    end

    private

    def kinds
      @kinds ||= episodes.flat_map { |episode| episode.medications.map(&:kind) }
    end
  end

  attr_reader :months

  # `months` are first-of-month dates; every episode of those months is loaded once.
  def initialize(user, months:)
    @months = months
    range = months.first..months.last.end_of_month
    @episodes_by_date = user.episodes.includes(:medications).where(occurred_on: range).chronological.group_by(&:occurred_on)
  end

  def day(date)
    Day.new(date, @episodes_by_date.fetch(date, []))
  end

  def days_of(month)
    (month..month.end_of_month).map { |date| day(date) }
  end

  def pain_days(month)
    days_of(month).count(&:pain?)
  end

  def treatment_days(month)
    days_of(month).count(&:treatment?)
  end

  # The three months of the paper sheet that contains `month`: Jan-Mar, Apr-Jun, Jul-Sep, Oct-Dec.
  def self.quarter_of(month)
    first = Date.new(month.year, ((month.month - 1) / 3) * 3 + 1, 1)
    (0..2).map { |offset| first.advance(months: offset) }
  end
end
