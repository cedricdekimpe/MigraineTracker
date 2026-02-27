# frozen_string_literal: true

class MigraineSerializer
  include JSONAPI::Serializer

  attributes :occurred_on, :nature, :intensity, :on_period, :created_at, :updated_at

  attribute :nature_label do |migraine|
    I18n.t("migraine_nature.#{migraine.nature}", default: migraine.nature)
  end

  belongs_to :medication, serializer: MedicationSerializer, if: proc { |migraine| migraine.medication.present? }
end
