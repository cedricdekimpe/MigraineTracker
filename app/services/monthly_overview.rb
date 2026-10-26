# frozen_string_literal: true

# Month-by-month figures in the unit neurologists use: days, not episodes.
#
# - migraine day: at least one migraine-type pain episode that day
# - moderate-to-severe day: a pain day whose strongest episode reaches 4 out of 10 (there is no official
#   cut-off on the 0-10 scale; 4 is the usual convention for "moderate")
# - headache day: pain, but no migraine episode that day
# - aura day: an aura without any pain that day
# - acute / triptan days: days with an intake of an acute treatment (X) / a triptan (t)
#
# Overuse is read on three levels, from the most cautious to the diagnostic one:
#   advised  above the practical limits of the IHS 2024 recommendations (simple analgesics and NSAIDs
#            under 10 days a month and 3 a week; triptans and combined analgesics under 8 days a month
#            and 2 a week): taking treatment more often than that is how overuse starts
#   over     an ICHD-3 threshold is reached in the month: 10+ days of triptans, 10+ days of combined
#            analgesics or opioids, 15+ days of simple analgesics or NSAIDs, or 10+ days when several
#            classes are mixed
#   sustained  that threshold was reached 3 months in a row, which is what the ICHD-3 criterion asks
#            for (and still only a reminder to see a doctor, not a diagnosis)
# Gepants and ditans have no threshold of their own but count in the mix.
class MonthlyOverview
  TRIPTAN_LIMIT = 10
  COMBINATION_LIMIT = 10
  ACUTE_LIMIT = 15
  MIXED_LIMIT = 10

  # Intensity from which a pain day is "moderate to severe"
  SEVERE_FROM = 4
  TRIPTAN_ADVISED = 8
  COMBINATION_ADVISED = 8
  ACUTE_ADVISED = 10
  MIXED_ADVISED = 8
  # Days of treatment in a Monday-to-Sunday week above which the week counts as a heavy one
  ACUTE_WEEK_ADVISED = 3
  TRIPTAN_WEEK_ADVISED = 2

  Month = Struct.new(:month, :migraine_days, :headache_days, :aura_days, :triptan_days, :acute_days, :combination_days,
                     :gepant_days, :non_triptan_days, :any_acute_days, :heavy_weeks, :streak, :severe_days, keyword_init: true) do
    def pain_days
      migraine_days + headache_days
    end

    # Chronic migraine (ICHD-3 1.3) asks for 15+ headache days with 8+ migraine days a month, for over 3 months.
    def chronic_pattern?
      pain_days >= 15 && migraine_days >= 8
    end

    def mixed?
      [ triptan_days, acute_days, combination_days, gepant_days ].count(&:positive?) > 1
    end

    # An ICHD-3 threshold is reached this month.
    def threshold_reached?
      triptan_days >= TRIPTAN_LIMIT || combination_days >= COMBINATION_LIMIT || acute_days >= ACUTE_LIMIT ||
        (mixed? && any_acute_days >= MIXED_LIMIT)
    end

    # Above the practical limits advised by the IHS, by the month or in any week starting in it.
    def advised_limit_exceeded?
      triptan_days >= TRIPTAN_ADVISED || combination_days >= COMBINATION_ADVISED || acute_days >= ACUTE_ADVISED ||
        (mixed? && any_acute_days >= MIXED_ADVISED) || heavy_weeks.positive?
    end

    def overuse_status
      if threshold_reached?
        streak >= 3 ? :sustained : :over
      elsif advised_limit_exceeded?
        :advised
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

  # How many months in a row, up to the latest one, show the chronic migraine pattern (15+ headache
  # days with 8+ migraine days). The month under way counts only once it already matches.
  def chronic_streak
    months.reverse.take_while(&:chronic_pattern?).size
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
    episodes = @user.episodes.where(occurred_on: range).pluck(:occurred_on, :pain_kind, :aura, :intensity)
    # Weeks run Monday to Sunday and may start before the first month: load their days too.
    week_range = first.beginning_of_week..last.end_of_month.end_of_week
    all_intakes = MedicationIntake.joins(:medication, :episode)
                                  .where(episodes: { user_id: @user.id, occurred_on: week_range }, medications: { kind: Medication::COUNTED_KINDS })
                                  .pluck("episodes.occurred_on", "medications.kind")
    intakes = all_intakes.select { |date, _| range.cover?(date) }
    kinds_by_day = all_intakes.group_by(&:first).transform_values { |rows| rows.map(&:last).uniq }

    by_day = episodes.group_by(&:first)
    months = (0...count).map do |offset|
      month = first.advance(months: offset)
      days = by_day.select { |date, _| date.beginning_of_month == month }
      month_intakes = intakes.select { |date, _| date.beginning_of_month == month }

      Month.new(
        month: month,
        migraine_days: days.count { |_, rows| rows.any? { |_, pain, _| pain == "migraine" } },
        headache_days: days.count { |_, rows| rows.none? { |_, pain, _| pain == "migraine" } && rows.any? { |_, pain, _| pain == "headache" } },
        aura_days: days.count { |_, rows| rows.none? { |_, pain, _| pain.present? } && rows.any? { |_, _, aura| aura } },
        severe_days: days.count { |_, rows| rows.any? { |_, pain, _, intensity| pain.present? && intensity.to_i >= SEVERE_FROM } },
        triptan_days: month_intakes.select { |_, kind| kind == "triptan" }.map(&:first).uniq.size,
        acute_days: month_intakes.select { |_, kind| kind == "acute" }.map(&:first).uniq.size,
        combination_days: month_intakes.select { |_, kind| kind == "combination" }.map(&:first).uniq.size,
        gepant_days: month_intakes.select { |_, kind| kind == "gepant" }.map(&:first).uniq.size,
        non_triptan_days: month_intakes.reject { |_, kind| kind == "triptan" }.map(&:first).uniq.size,
        any_acute_days: month_intakes.map(&:first).uniq.size,
        heavy_weeks: heavy_weeks(month, kinds_by_day),
        streak: 0
      )
    end

    previous = 0
    months.each do |month|
      previous = month.threshold_reached? ? previous + 1 : 0
      month.streak = previous
    end
    months
  end

  # Weeks (Monday to Sunday) starting in the month with more days of treatment than the advised weekly limits.
  def heavy_weeks(month, kinds_by_day)
    weeks = (month..month.end_of_month).select(&:monday?)
    weeks.count do |monday|
      days = (monday..monday + 6).map { |date| kinds_by_day.fetch(date, []) }
      days.count { |kinds| kinds.include?("acute") } > ACUTE_WEEK_ADVISED ||
        days.count { |kinds| (kinds & %w[triptan combination]).any? } > TRIPTAN_WEEK_ADVISED
    end
  end
end
