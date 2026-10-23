# frozen_string_literal: true

# Imports a backup (as produced by ExportsController / Api::V1::DataController#export)
# into a user's account. All-or-nothing: any invalid row aborts the whole import.
#
# Only DataImporter::InvalidData is meant to be rescued by callers; its message is
# written for the end user and never contains internal exception details.
class DataImporter
  MAX_MEDICATIONS = 500
  MAX_MIGRAINES = 20_000

  Result = Struct.new(:medications, :migraines, keyword_init: true)

  class InvalidData < StandardError; end

  def initialize(user, data)
    @user = user
    @data = data
  end

  def call
    validate_shape!

    result = Result.new(medications: 0, migraines: 0)
    ActiveRecord::Base.transaction do
      @medications = @user.medications.index_by { |medication| medication_key(medication.name) }
      @existing_dates = @user.migraines.pluck(:occurred_on).to_set

      Array(@data["medications"]).each_with_index { |row, index| import_medication(row, index, result) }
      Array(@data["migraines"]).each_with_index { |row, index| import_migraine(row, index, result) }
    end
    result
  end

  private

  def validate_shape!
    raise InvalidData, t("invalid_structure") unless @data.is_a?(Hash)

    medications = @data["medications"]
    migraines = @data["migraines"]

    raise InvalidData, t("invalid_structure") unless migraines.is_a?(Array)
    raise InvalidData, t("invalid_structure") unless medications.nil? || medications.is_a?(Array)
    raise InvalidData, t("too_many", what: t("medications_label"), max: MAX_MEDICATIONS) if medications.to_a.size > MAX_MEDICATIONS
    raise InvalidData, t("too_many", what: t("migraines_label"), max: MAX_MIGRAINES) if migraines.size > MAX_MIGRAINES
  end

  def import_medication(row, index, result)
    fail_row = -> { raise InvalidData, t("invalid_row", kind: t("medication_kind"), index: index + 1, details: t("invalid_name")) }
    fail_row.call unless row.is_a?(Hash) && row["name"].is_a?(String)

    find_or_create_medication(row["name"], result, &fail_row)
  end

  def import_migraine(row, index, result)
    fail_row = ->(details) { raise InvalidData, t("invalid_row", kind: t("migraine_kind"), index: index + 1, details: details) }
    fail_row.call(t("invalid_row_shape")) unless row.is_a?(Hash)

    occurred_on = parse_date(row["occurred_on"]) || fail_row.call(t("invalid_date"))
    return if @existing_dates.include?(occurred_on)

    medication = find_or_create_medication(row["medication_name"], result) { fail_row.call(t("invalid_name")) }

    migraine = @user.migraines.new(
      occurred_on: occurred_on,
      nature: row["nature"],
      intensity: row["intensity"],
      on_period: ActiveModel::Type::Boolean.new.cast(row["on_period"]) || false,
      medication: medication
    )
    fail_row.call(migraine.errors.full_messages.to_sentence) unless migraine.save

    @existing_dates << occurred_on
    result.migraines += 1
  end

  # Returns nil for a blank name (no medication); yields when the name is unusable.
  def find_or_create_medication(name, result)
    return nil if name.nil? || (name.is_a?(String) && name.strip.empty?)

    yield unless name.is_a?(String)

    key = medication_key(name)
    @medications[key] ||= begin
      medication = @user.medications.new(name: name)
      yield unless medication.save
      result.medications += 1
      medication
    end
  end

  def medication_key(name)
    name.to_s.strip.downcase
  end

  # Strict ISO 8601 calendar date (YYYY-MM-DD); anything else is rejected.
  def parse_date(value)
    return nil unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

    Date.iso8601(value)
  rescue Date::Error
    nil
  end

  def t(key, **options)
    I18n.t("import.errors.#{key}", **options)
  end
end
