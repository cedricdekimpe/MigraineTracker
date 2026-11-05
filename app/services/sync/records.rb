# frozen_string_literal: true

module Sync
  # The JSON shape of each synced record (docs/API.md). Dates are "YYYY-MM-DD", times of day "HH:MM",
  # instants ISO 8601 with microseconds.
  module Records
    # The names the API uses for each kind of record
    TYPE_NAMES = { "episode" => "Episode", "period_day" => "PeriodDay", "daily_check" => "DailyCheck" }.freeze

    module_function

    def episode(episode)
      {
        uuid: episode.uuid,
        occurred_on: episode.occurred_on.iso8601,
        started_time: episode.started_time&.strftime("%H:%M"),
        duration_minutes: episode.duration_minutes,
        aura: episode.aura,
        pain_kind: episode.pain_kind,
        intensity: episode.intensity,
        nausea: episode.nausea,
        notes: episode.notes,
        ongoing: episode.ongoing,
        trigger_ids: episode.episode_triggers.map(&:trigger_id).sort,
        medication_intakes: episode.medication_intakes.map do |intake|
          { uuid: intake.uuid, medication_id: intake.medication_id, dose: intake.dose,
            taken_time: intake.taken_time&.strftime("%H:%M"), effect: intake.effect }
        end,
        updated_at: episode.updated_at.iso8601(6)
      }
    end

    def period_day(day)
      { uuid: day.uuid, date: day.date.iso8601, updated_at: day.updated_at.iso8601(6) }
    end

    def daily_check(check)
      { uuid: check.uuid, date: check.date.iso8601, sleep: check.sleep, stress: check.stress,
        skipped_meal: check.skipped_meal, caffeine: check.caffeine, updated_at: check.updated_at.iso8601(6) }
    end

    def medication(medication)
      { id: medication.id, name: medication.name, kind: medication.kind, default_dose: medication.default_dose,
        archived: medication.archived_at.present? }
    end
  end
end
