# frozen_string_literal: true

class EpisodeSerializer
  include JSONAPI::Serializer

  attributes :occurred_on, :duration_minutes, :aura, :pain_kind, :intensity, :on_period, :notes, :created_at, :updated_at

  attribute :started_time do |episode|
    episode.started_time&.strftime("%H:%M")
  end

  attribute :code, &:code

  attribute :triggers do |episode|
    episode.triggers.map { |trigger| { id: trigger.id, name: trigger.name } }
  end

  attribute :medications do |episode|
    episode.medication_intakes.map do |intake|
      {
        id: intake.id,
        medication_id: intake.medication_id,
        name: intake.medication.name,
        dose: intake.dose,
        taken_time: intake.taken_time&.strftime("%H:%M"),
        effect: intake.effect
      }
    end
  end
end
