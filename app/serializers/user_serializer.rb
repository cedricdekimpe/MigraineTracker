# frozen_string_literal: true

class UserSerializer
  include JSONAPI::Serializer

  attributes :email, :created_at, :updated_at

  attribute :migraines_count do |user|
    user.migraines.count
  end

  attribute :medications_count do |user|
    user.medications.count
  end
end
