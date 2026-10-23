# frozen_string_literal: true

class UserSerializer
  include JSONAPI::Serializer

  attributes :email, :created_at, :updated_at

  attributes :track_cycle

  attribute :episodes_count do |user|
    user.episodes.count
  end

  attribute :medications_count do |user|
    user.medications.count
  end
end
