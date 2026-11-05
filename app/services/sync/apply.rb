# frozen_string_literal: true

module Sync
  # Changes the mobile app sends (POST /api/v1/changes): whole records made or edited on the phone, possibly
  # offline, and deletions. The most recent version wins: a record edited on the server after the phone's edit
  # is kept as it is ("stale"), and the phone takes the server's copy at its next GET. Each record is saved on
  # its own: one invalid record does not stop the others.
  class Apply
    class TooLarge < StandardError; end

    LIMIT = 500
    EPISODE_FIELDS = %w[occurred_on started_time duration_minutes aura pain_kind intensity nausea notes ongoing].freeze
    CHECK_FIELDS = %w[sleep stress skipped_meal caffeine].freeze

    def initialize(user, body, now: Time.current)
      @user = user
      @now = now
      @episodes = list(body, "episodes")
      @period_days = list(body, "period_days")
      @daily_checks = list(body, "daily_checks")
      @deletions = list(body, "deletions")
      raise TooLarge if [ @episodes, @period_days, @daily_checks, @deletions ].sum(&:size) > LIMIT
    end

    # One result per record sent: { type:, uuid:, status:, errors: (when invalid), uuid_now: (when merged) }
    def call
      @episodes.map { |item| guard("episode", item) { episode(item) } } +
        @period_days.map { |item| guard("period_day", item) { period_day(item) } } +
        @daily_checks.map { |item| guard("daily_check", item) { daily_check(item) } } +
        @deletions.map { |item| guard(item["type"].to_s, item) { deletion(item) } }
    end

    private

    def list(body, key)
      value = body[key]
      value.is_a?(Array) ? value.select { |item| item.is_a?(Hash) } : []
    end

    def guard(type, item)
      uuid = item["uuid"].to_s.downcase
      result = { type: type, uuid: uuid }
      return result.merge(status: "invalid", errors: { uuid: [ "invalid" ] }) unless uuid.match?(Synced::UUID_FORMAT)

      result.merge(yield(uuid))
    rescue ActiveRecord::RecordNotUnique
      result.merge(status: "invalid", errors: { uuid: [ "taken" ] })
    end

    # When the phone made its change; a phone clock in the future counts as now
    def edited_at(item, key = "updated_at")
      [ Time.iso8601(item[key].to_s), @now ].min
    rescue ArgumentError
      @now
    end

    def episode(item)
      episode = @user.episodes.includes(:medication_intakes).find_by(uuid: item["uuid"].downcase)
      return taken if episode.nil? && Episode.exists?(uuid: item["uuid"].downcase)
      return { status: "stale" } if episode && episode.updated_at > edited_at(item)

      episode ||= @user.episodes.new(uuid: item["uuid"].downcase, aura: false, ongoing: false)
      # Fields left out keep their value
      episode.assign_attributes(item.slice(*EPISODE_FIELDS))
      replace_intakes(episode, item["medication_intakes"])
      save(episode) { episode.trigger_ids = trigger_ids(item["trigger_ids"]) }
    end

    # The intakes sent are the episode's intakes: the others go
    def replace_intakes(episode, items)
      existing = episode.medication_intakes.index_by(&:uuid)
      Array(items).select { |i| i.is_a?(Hash) }.each do |data|
        intake = existing.delete(data["uuid"].to_s.downcase) || episode.medication_intakes.build(uuid: data["uuid"])
        intake.assign_attributes(data.slice("medication_id", "dose", "taken_time", "effect"))
      end
      existing.each_value(&:mark_for_destruction)
    end

    # Only the account's own triggers
    def trigger_ids(ids)
      @user.triggers.where(id: Array(ids)).pluck(:id)
    end

    def period_day(item)
      day = @user.period_days.find_by(uuid: item["uuid"].downcase)
      return taken if day.nil? && PeriodDay.exists?(uuid: item["uuid"].downcase)

      date = item["date"]
      if day
        return { status: "unchanged" } if day.date.iso8601 == date.to_s
        return { status: "stale" } if day.updated_at > edited_at(item)

        day.date = date
        return save(day)
      end

      # The same day marked on another device or on the web: one day, the server's
      other = @user.period_days.find_by(date: date)
      return { status: "merged", uuid_now: other.uuid } if other

      save(@user.period_days.new(uuid: item["uuid"].downcase, date: date))
    end

    def daily_check(item)
      check = @user.daily_checks.find_by(uuid: item["uuid"].downcase)
      return taken if check.nil? && DailyCheck.exists?(uuid: item["uuid"].downcase)

      # A check-in of the same day made elsewhere is the same check-in
      merged = check.nil? && (check = @user.daily_checks.find_by(date: item["date"]))
      return { status: "stale", **(merged ? { uuid_now: check.uuid } : {}) } if check && check.updated_at > edited_at(item)

      check ||= @user.daily_checks.new(uuid: item["uuid"].downcase)
      check.assign_attributes(item.slice("date", *CHECK_FIELDS))
      result = save(check)
      merged && result[:status] == "saved" ? result.merge(status: "merged", uuid_now: check.uuid) : result
    end

    def deletion(item)
      class_name = Sync::Records::TYPE_NAMES[item["type"].to_s]
      return { status: "invalid", errors: { type: [ "invalid" ] } } unless class_name

      record = class_name.constantize.where(user: @user).find_by(uuid: item["uuid"].downcase)
      return { status: "gone" } unless record
      return { status: "stale" } if record.updated_at > edited_at(item, "deleted_at")

      record.destroy!
      { status: "deleted" }
    end

    def save(record)
      saved = record.class.transaction do
        yield if block_given?
        record.save || raise(ActiveRecord::Rollback)
      end
      saved ? { status: "saved" } : { status: "invalid", errors: codes(record) }
    end

    # Validation errors as codes ("blank", "invalid"…), the app writes the words
    def codes(record)
      errors = record.errors.details.transform_values { |list| list.map { |detail| detail[:error].to_s } }
      record.try(:medication_intakes)&.each do |intake|
        intake.errors.details.each { |attribute, list| (errors[:"medication_intakes.#{attribute}"] ||= []).concat(list.map { |d| d[:error].to_s }) }
      end
      errors
    end

    def taken
      { status: "invalid", errors: { uuid: [ "taken" ] } }
    end
  end
end
