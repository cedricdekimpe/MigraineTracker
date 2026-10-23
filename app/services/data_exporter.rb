# frozen_string_literal: true

# Builds the JSON backup of a user's data (format version 3). DataImporter reads the same shape back.
class DataExporter
  FORMAT_VERSION = 3

  def initialize(user)
    @user = user
  end

  def as_hash
    {
      format_version: FORMAT_VERSION,
      exported_at: Time.current.iso8601,
      user_email: @user.email,
      medications: medications.map { |medication| medication_hash(medication) },
      triggers: triggers.map { |trigger| { name: trigger.name } },
      period_days: @user.period_days.order(:date).pluck(:date).map(&:iso8601),
      episodes: episodes.map { |episode| episode_hash(episode) }
    }
  end

  private

  def medications
    @medications ||= @user.medications.order(:name)
  end

  def triggers
    @triggers ||= @user.triggers.alphabetical
  end

  def episodes
    @episodes ||= @user.episodes.includes(medication_intakes: :medication).includes(:triggers).order(:occurred_on, :started_time, :id)
  end

  def medication_hash(medication)
    {
      name: medication.name,
      kind: medication.kind,
      default_dose: medication.default_dose,
      archived: medication.archived?,
      created_at: medication.created_at.iso8601
    }
  end

  def episode_hash(episode)
    {
      occurred_on: episode.occurred_on.iso8601,
      started_time: episode.started_time&.strftime("%H:%M"),
      duration_minutes: episode.duration_minutes,
      aura: episode.aura,
      pain_kind: episode.pain_kind,
      intensity: episode.intensity,
      notes: episode.notes,
      triggers: episode.triggers.map(&:name).sort,
      medications: episode.medication_intakes.map do |intake|
        { name: intake.medication.name, dose: intake.dose, taken_time: intake.taken_time&.strftime("%H:%M"), effect: intake.effect }
      end,
      created_at: episode.created_at.iso8601
    }
  end
end
