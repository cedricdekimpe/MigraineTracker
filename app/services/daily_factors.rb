# frozen_string_literal: true

# Compares days that followed a factor with the days that did not, using the daily check-ins.
#
# For each factor and each delay (the same day, the next day, two days later) it gives the share of
# days with pain after the factor against the share after the other checked days. Only checked days
# count, and an attack day is any day with pain. It shows an association in one person's own journal,
# not a proof of cause, and says nothing until there are enough days to compare.
class DailyFactors
  FACTORS = {
    poor_sleep: ->(check, _previous) { check.sleep && check.sleep != "good" },
    high_stress: ->(check, _previous) { check.stress && check.stress == "high" },
    stress_drop: ->(check, previous) { previous && check.stress_level && previous.stress_level && previous.stress_level - check.stress_level >= 1 },
    skipped_meal: ->(check, _previous) { check.skipped_meal },
    caffeine_high: ->(check, _previous) { check.caffeine && check.caffeine == "high" }
  }.freeze
  LAGS = [0, 1, 2].freeze

  MIN_CHECKED_DAYS = 30
  MIN_EXPOSED_DAYS = 8
  # Difference in points between the two shares from which a link is worth mentioning
  NOTABLE_GAP = 15

  Result = Struct.new(:factor, :lag, :exposed_days, :exposed_pain_days, :other_days, :other_pain_days, keyword_init: true) do
    def exposed_share
      (exposed_pain_days * 100.0 / exposed_days).round
    end

    def other_share
      (other_pain_days * 100.0 / other_days).round
    end

    def gap
      exposed_share - other_share
    end

    def notable?
      exposed_days >= MIN_EXPOSED_DAYS && gap >= NOTABLE_GAP
    end
  end

  def initialize(user, today: Date.current)
    @user = user
    @today = today
  end

  def checked_days
    checks.size
  end

  # Enough days of check-ins to compare anything
  def enough_data?
    checked_days >= MIN_CHECKED_DAYS
  end

  # Results for every factor and delay with something to compare, empty until there is enough data.
  def results
    return [] unless enough_data?

    @results ||= FACTORS.keys.flat_map { |factor| LAGS.filter_map { |lag| result(factor, lag) } }
  end

  # The factors with at least one notable delay, strongest first.
  def notable
    results.select(&:notable?).group_by(&:factor).map { |_, rows| rows.max_by(&:gap) }.sort_by { |row| -row.gap }
  end

  private

  def checks
    @checks ||= @user.daily_checks.order(:date).to_a
  end

  def checks_by_date
    @checks_by_date ||= checks.index_by(&:date)
  end

  def pain_dates
    @pain_dates ||= @user.episodes.where.not(pain_kind: nil).distinct.pluck(:occurred_on).to_set
  end

  def result(factor, lag)
    exposed = [0, 0]
    other = [0, 0]

    checks.each do |check|
      outcome_day = check.date + lag
      next if outcome_day > @today

      flag = FACTORS.fetch(factor).call(check, checks_by_date[check.date - 1])
      next if flag.nil?

      bucket = flag ? exposed : other
      bucket[0] += 1
      bucket[1] += 1 if pain_dates.include?(outcome_day)
    end

    return nil if exposed[0].zero? || other[0].zero?

    Result.new(factor: factor, lag: lag, exposed_days: exposed[0], exposed_pain_days: exposed[1], other_days: other[0], other_pain_days: other[1])
  end
end
