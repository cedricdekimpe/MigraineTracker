# frozen_string_literal: true

# Month-by-month figures in the unit neurologists use: days, not episodes.
#
# - migraine day: at least one migraine-type pain episode that day
# - headache day: pain, but no migraine episode that day
# - aura day: an aura without any pain that day
# - acute / triptan days: days with an intake of an acute treatment (X) / a triptan (t)
#
# Overuse follows the ICHD-3 thresholds, counted per month: 10+ triptan days, 15+ days of other acute
# treatments, or 10+ days when both kinds are mixed (the criterion also asks for more than 3 months
# of regular use, which is why this is shown as a warning, not a diagnosis).
class MonthlyOverview
  TRIPTAN_LIMIT = 10
  ACUTE_LIMIT = 15
  MIXED_LIMIT = 10
  WATCH_RATIO = 0.8

  Month = Struct.new(:month, :migraine_days, :headache_days, :aura_days, :triptan_days, :acute_days, :any_acute_days, keyword_init: true) do
    def pain_days
      migraine_days + headache_days
    end

    def mixed?
      triptan_days.positive? && acute_days.positive?
    end

    def overuse_status
      ratios = [triptan_days.to_f / TRIPTAN_LIMIT, acute_days.to_f / ACUTE_LIMIT]
      ratios << any_acute_days.to_f / MIXED_LIMIT if mixed?

      if ratios.max >= 1
        :over
      elsif ratios.max >= WATCH_RATIO
        :watch
      else
        :ok
      end
    end
  end

  attr_reader :months

  def initialize(user, months: 12, today: Date.current)
    @user = user
    first = today.beginning_of_month.advance(months: -(months - 1))
    @months = build(first, today.beginning_of_month, months)
  end

  def current
    months.last
  end

  # Average days with pain over the `count` complete months before the current one, starting from the
  # first month with any record (months before the user started logging are not zeros). nil if none.
  def average_pain_days(count = 3)
    first_used = months.index { |month| month.pain_days.positive? || month.aura_days.positive? || month.any_acute_days.positive? }
    return if first_used.nil?

    complete = months[first_used...-1].to_a.last(count)
    return if complete.empty?

    (complete.sum(&:pain_days).to_f / complete.size).round(1)
  end

  private

  def build(first, last, count)
    range = first..last.end_of_month
    episodes = @user.episodes.where(occurred_on: range).pluck(:occurred_on, :pain_kind, :aura)
    intakes = MedicationIntake.joins(:medication, :episode)
                              .where(episodes: { user_id: @user.id, occurred_on: range }, medications: { kind: %w[acute triptan] })
                              .pluck("episodes.occurred_on", "medications.kind")

    by_day = episodes.group_by(&:first)
    (0...count).map do |offset|
      month = first.advance(months: offset)
      days = by_day.select { |date, _| date.beginning_of_month == month }
      month_intakes = intakes.select { |date, _| date.beginning_of_month == month }

      Month.new(
        month: month,
        migraine_days: days.count { |_, rows| rows.any? { |_, pain, _| pain == "migraine" } },
        headache_days: days.count { |_, rows| rows.none? { |_, pain, _| pain == "migraine" } && rows.any? { |_, pain, _| pain == "headache" } },
        aura_days: days.count { |_, rows| rows.none? { |_, pain, _| pain.present? } && rows.any? { |_, _, aura| aura } },
        triptan_days: month_intakes.select { |_, kind| kind == "triptan" }.map(&:first).uniq.size,
        acute_days: month_intakes.select { |_, kind| kind == "acute" }.map(&:first).uniq.size,
        any_acute_days: month_intakes.map(&:first).uniq.size
      )
    end
  end
end
