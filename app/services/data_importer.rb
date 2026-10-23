# frozen_string_literal: true

# Imports a backup (as produced by DataExporter, format version 2) into a user's account.
# All-or-nothing: any invalid row aborts the whole import.
#
# Only DataImporter::InvalidData is meant to be rescued by callers; its message is
# written for the end user and never contains internal exception details.
class DataImporter
  MAX_MEDICATIONS = 500
  MAX_TRIGGERS = 200
  MAX_EPISODES = 20_000
  MAX_PERIOD_DAYS = 10_000
  TIME_FORMAT = /\A([01]\d|2[0-3]):[0-5]\d\z/

  Result = Struct.new(:medications, :triggers, :episodes, :period_days, :treatment_periods, keyword_init: true)

  class InvalidData < StandardError; end

  def initialize(user, data)
    @user = user
    @data = data
  end

  def call
    validate_shape!

    result = Result.new(medications: 0, triggers: 0, episodes: 0, period_days: 0, treatment_periods: 0)
    ActiveRecord::Base.transaction do
      @medications = @user.medications.index_by { |medication| key(medication.name) }
      @triggers = @user.triggers.index_by { |trigger| key(trigger.name) }
      @legacy_period_dates = []
      @seen = @user.episodes.map { |episode| signature(episode.occurred_on, episode.started_time&.strftime("%H:%M"), episode.pain_kind, episode.aura, episode.intensity, episode.duration_minutes) }.to_set

      list("medications").each_with_index { |row, index| import_medication_row(row, index, result) }
      list("triggers").each_with_index { |row, index| import_trigger_row(row, index, result) }
      list("episodes").each_with_index { |row, index| import_episode(row, index, result) }
      import_period_days(result)
    end
    result
  end

  private

  def list(name)
    @data[name] || []
  end

  def validate_shape!
    raise InvalidData, t("invalid_structure") unless @data.is_a?(Hash)
    raise InvalidData, t("invalid_structure") unless @data["episodes"].is_a?(Array)

    %w[medications triggers period_days].each do |name|
      raise InvalidData, t("invalid_structure") unless @data[name].nil? || @data[name].is_a?(Array)
    end

    raise InvalidData, t("too_many", what: t("medications_label"), max: MAX_MEDICATIONS) if list("medications").size > MAX_MEDICATIONS
    raise InvalidData, t("too_many", what: t("triggers_label"), max: MAX_TRIGGERS) if list("triggers").size > MAX_TRIGGERS
    raise InvalidData, t("too_many", what: t("episodes_label"), max: MAX_EPISODES) if list("episodes").size > MAX_EPISODES
    raise InvalidData, t("too_many", what: t("period_days_label"), max: MAX_PERIOD_DAYS) if list("period_days").size > MAX_PERIOD_DAYS
  end

  def import_medication_row(row, index, result)
    fail_row = -> { raise InvalidData, row_message("medication_kind", index, t("invalid_name")) }
    fail_row.call unless row.is_a?(Hash) && row["name"].is_a?(String)

    medication = find_or_create_medication(row["name"], result, kind: row["kind"], default_dose: row["default_dose"], archived: row["archived"], &fail_row)
    import_periods(medication, row["periods"], index, result) if medication
  end

  # Dated periods of a preventive; one already on record for the same start date is left as it is.
  def import_periods(medication, periods, index, result)
    return if periods.nil?

    fail_row = ->(details) { raise InvalidData, row_message("medication_kind", index, details) }
    fail_row.call(t("invalid_row_shape")) unless periods.is_a?(Array)

    periods.each do |data|
      fail_row.call(t("invalid_row_shape")) unless data.is_a?(Hash)
      started_on = parse_date(data["started_on"]) || fail_row.call(t("invalid_date"))
      ended_on = data["ended_on"].nil? ? nil : (parse_date(data["ended_on"]) || fail_row.call(t("invalid_date")))
      next if medication.treatment_periods.exists?(started_on: started_on)

      period = medication.treatment_periods.new(user: @user, started_on: started_on, ended_on: ended_on,
                                                dose: data["dose"].is_a?(String) ? data["dose"] : nil, stop_reason: data["stop_reason"])
      fail_row.call(period.errors.full_messages.to_sentence) unless period.save
      result.treatment_periods += 1
    end
  end

  def import_trigger_row(row, index, result)
    name = row.is_a?(Hash) ? row["name"] : row
    find_or_create_trigger(name, result) { raise InvalidData, row_message("trigger_kind", index, t("invalid_name")) }
  end

  def import_period_days(result)
    dates = list("period_days").each_with_index.map do |value, index|
      parse_date(value) || raise(InvalidData, row_message("period_day_kind", index, t("invalid_date")))
    end
    existing = @user.period_days.pluck(:date).to_set

    (dates + @legacy_period_dates).uniq.each do |date|
      next if existing.include?(date)

      @user.period_days.create!(date: date)
      result.period_days += 1
    end
  end

  def import_episode(row, index, result)
    fail_row = ->(details) { raise InvalidData, row_message("episode_kind", index, details) }
    fail_row.call(t("invalid_row_shape")) unless row.is_a?(Hash)

    occurred_on = parse_date(row["occurred_on"]) || fail_row.call(t("invalid_date"))
    started_time = parse_time(row["started_time"]) { fail_row.call(t("invalid_time")) }
    # Backups of format 2 flagged the period on the episode; it is a day of its own now.
    @legacy_period_dates << occurred_on if ActiveModel::Type::Boolean.new.cast(row["on_period"])

    episode = @user.episodes.new(
      occurred_on: occurred_on,
      started_time: started_time,
      duration_minutes: row["duration_minutes"],
      aura: ActiveModel::Type::Boolean.new.cast(row["aura"]) || false,
      pain_kind: row["pain_kind"],
      intensity: row["intensity"],
      notes: row["notes"].is_a?(String) ? row["notes"] : nil
    )

    sign = signature(occurred_on, started_time, episode.pain_kind, episode.aura, episode.intensity, episode.duration_minutes)
    return if @seen.include?(sign)

    Array(row["medications"]).each do |intake|
      fail_row.call(t("invalid_row_shape")) unless intake.is_a?(Hash)
      medication = find_or_create_medication(intake["name"], result) { fail_row.call(t("invalid_name")) }
      next unless medication

      taken_time = parse_time(intake["taken_time"]) { fail_row.call(t("invalid_time")) }
      episode.medication_intakes.build(medication: medication, dose: intake["dose"].to_s, taken_time: taken_time, effect: intake["effect"])
    end

    Array(row["triggers"]).each do |name|
      trigger = find_or_create_trigger(name, result) { fail_row.call(t("invalid_name")) }
      episode.triggers << trigger if trigger && !episode.triggers.include?(trigger)
    end

    fail_row.call(episode.errors.full_messages.to_sentence) unless episode.save

    @seen << sign
    result.episodes += 1
  end

  # Returns nil for a blank name; yields when the name is unusable. Existing medications
  # (archived or not) are reused as-is, never un-archived by an import.
  def find_or_create_medication(name, result, kind: nil, default_dose: nil, archived: false)
    return nil if blank_name?(name)

    yield unless name.is_a?(String)

    @medications[key(name)] ||= begin
      medication = @user.medications.new(name: name, default_dose: default_dose.is_a?(String) ? default_dose : nil)
      medication.kind = kind if Medication::KINDS.include?(kind)
      medication.archived_at = Time.current if ActiveModel::Type::Boolean.new.cast(archived)
      yield unless medication.save
      result.medications += 1
      medication
    end
  end

  def find_or_create_trigger(name, result)
    return nil if blank_name?(name)

    yield unless name.is_a?(String)

    @triggers[key(name)] ||= begin
      trigger = @user.triggers.new(name: name)
      yield unless trigger.save
      result.triggers += 1
      trigger
    end
  end

  def blank_name?(name)
    name.nil? || (name.is_a?(String) && name.strip.empty?)
  end

  def key(name)
    name.to_s.strip.downcase
  end

  def signature(*parts)
    parts.map { |part| part.respond_to?(:iso8601) && !part.is_a?(String) ? part.iso8601 : part.to_s }
  end

  # Strict ISO 8601 calendar date (YYYY-MM-DD); anything else is rejected.
  def parse_date(value)
    return nil unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

    Date.iso8601(value)
  rescue Date::Error
    nil
  end

  # "HH:MM" or nil; yields on anything else.
  def parse_time(value)
    return nil if value.nil? || value == ""

    yield unless value.is_a?(String) && value.match?(TIME_FORMAT)

    value
  end

  def row_message(kind, index, details)
    t("invalid_row", kind: t(kind), index: index + 1, details: details)
  end

  def t(key, **options)
    I18n.t("import.errors.#{key}", **options)
  end
end
