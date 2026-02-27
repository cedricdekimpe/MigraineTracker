# frozen_string_literal: true

class MedicationSerializer
  include JSONAPI::Serializer

  attributes :name, :created_at, :updated_at

  attribute :migraines_count do |medication|
    medication.migraines.count
  end
end
