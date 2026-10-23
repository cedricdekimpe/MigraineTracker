# frozen_string_literal: true

class TriggerSerializer
  include JSONAPI::Serializer

  attributes :name, :created_at, :updated_at

  attribute :episodes_count do |trigger|
    trigger.episode_triggers.count
  end
end
