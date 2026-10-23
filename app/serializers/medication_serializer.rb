# frozen_string_literal: true

class MedicationSerializer
  include JSONAPI::Serializer

  attributes :name, :kind, :default_dose, :created_at, :updated_at

  attribute :archived, &:archived?

  attribute :episodes_count do |medication|
    medication.medication_intakes.distinct.count(:episode_id)
  end
end
