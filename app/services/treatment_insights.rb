# frozen_string_literal: true

# What a neurologist asks about treatment, worked out from the journal:
# - does each acute drug work? (the effect noted after each attack; the Belgian consensus calls a drug
#   a failure when it did nothing on 2 of 3 attacks)
# - how early is it taken? (taking it while the pain is mild is what works best)
# - did each preventive help? (pain days a month in the 90 days before it started, against the last 90
#   days on it; a drop of 50% or more is the usual yardstick)
# - do the attacks follow the cycle? (ICHD-3: day -2 to +3 around the first bleeding day, in at least
#   2 of 3 cycles)
# These are figures to talk over with a doctor, never advice to start or stop anything.
class TreatmentInsights
  VERDICT_WINDOW = 3
  WINDOW_DAYS = 90
  RESPONDER_DROP = 0.5

  AcuteRow = Struct.new(:medication, :intakes, :none, :partial, :good, :unrated, :verdict, keyword_init: true)
  PreventiveRow = Struct.new(:period, :before, :after, :drop, keyword_init: true) do
    def responder?
      !drop.nil? && drop >= RESPONDER_DROP
    end
  end
  MenstrualLink = Struct.new(:cycles, :with_attack, :outside_attacks, keyword_init: true) do
    def pattern?
      cycles >= 3 && with_attack >= 2
    end

    # Attacks only around the bleeding, none at any other time of the cycles looked at
    def pure?
      pattern? && outside_attacks.zero?
    end
  end

  def initialize(user, today: Date.current, since: nil, through: nil)
    @user = user
    @today = today
    @since = since || today - 1.year
    @through = through || today
  end

  # One row per acute medication used since `since`, the most used first.
  def acute_rows
    @acute_rows ||= all_intakes.group_by(&:medication).map do |medication, intakes|
      recent = intakes.select { |intake| in_scope?(intake) }
      next if recent.empty?

      effects = recent.map(&:effect)
      AcuteRow.new(
        medication: medication, intakes: recent.size,
        none: effects.count("none"), partial: effects.count("partial"), good: effects.count("good"), unrated: effects.count(nil),
        verdict: verdict(intakes)
      )
    end.compact.sort_by { |row| [-row.intakes, row.medication.name.downcase] }
  end

  # Median minutes between the start of an attack and its first treatment, with how many attacks it rests on.
  def median_delay
    return @median_delay if defined?(@median_delay)

    delays = all_intakes.select { |intake| in_scope?(intake) }
                        .group_by(&:episode).filter_map do |episode, intakes|
      next unless episode.started_time

      taken = intakes.filter_map(&:taken_time).min
      next unless taken

      minutes = (taken.hour * 60 + taken.min) - (episode.started_time.hour * 60 + episode.started_time.min)
      minutes if minutes >= 0
    end

    @median_delay = delays.empty? ? nil : { minutes: median(delays).round, attacks: delays.size }
  end

  def preventive_rows
    @preventive_rows ||= @user.treatment_periods.includes(:medication).chronological.map do |period|
      before = rate(period.started_on - WINDOW_DAYS, period.started_on - 1)
      last_day = period.ended_on || @today
      after = period.days(today: @today) >= WINDOW_DAYS ? rate(last_day - (WINDOW_DAYS - 1), last_day) : nil
      drop = before && after && before.positive? ? ((before - after) / before).round(2) : nil
      PreventiveRow.new(period: period, before: before, after: after, drop: drop)
    end
  end

  def menstrual_link
    return @menstrual_link if defined?(@menstrual_link)

    starts = cycle_starts.select { |date| date + 2 <= @today }.last(3)
    @menstrual_link = starts.empty? ? nil : build_menstrual_link(starts)
  end

  private

  def in_scope?(intake)
    intake.episode.occurred_on.between?(@since, @through)
  end

  def all_intakes
    @all_intakes ||= MedicationIntake.joins(:medication, :episode).includes(:medication, :episode)
                                     .where(episodes: { user_id: @user.id }, medications: { kind: Medication::COUNTED_KINDS })
                                     .sort_by { |intake| [intake.episode.occurred_on, intake.taken_time&.strftime("%H:%M").to_s, intake.id] }
  end

  # Judged on the last 3 attacks where an effect was noted.
  def verdict(intakes)
    rated = intakes.select(&:effect).last(VERDICT_WINDOW)
    return :too_early if rated.size < VERDICT_WINDOW

    rated.count { |intake| intake.effect == "none" } >= 2 ? :not_working : :working
  end

  # Pain days a month, over a window of days; nil when the journal did not cover the whole window.
  def rate(from, to)
    return nil if first_record_on.nil? || first_record_on > from

    days = pain_dates.count { |date| date.between?(from, to) }
    (days * 30.0 / ((to - from).to_i + 1)).round(1)
  end

  def pain_dates
    @pain_dates ||= @user.episodes.where.not(pain_kind: nil).distinct.pluck(:occurred_on)
  end

  def first_record_on
    @first_record_on ||= [@user.episodes.minimum(:occurred_on), @user.period_days.minimum(:date)].compact.min
  end

  def cycle_starts
    dates = @user.period_days.order(:date).pluck(:date)
    set = dates.to_set
    dates.reject { |date| set.include?(date - 1) }
  end

  def build_menstrual_link(starts)
    windows = starts.map { |start| (start - 2)..(start + 2) }
    span_end = [starts.last + 27, @today].min
    span = (starts.first - 2)..span_end
    attacks = pain_dates.select { |date| span.cover?(date) }
    in_window = windows.count { |window| attacks.any? { |date| window.cover?(date) } }
    outside = attacks.count { |date| windows.none? { |window| window.cover?(date) } }

    MenstrualLink.new(cycles: starts.size, with_attack: in_window, outside_attacks: outside)
  end

  def median(values)
    sorted = values.sort
    middle = sorted.size / 2
    sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
  end
end
