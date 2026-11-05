# frozen_string_literal: true

# A record the mobile app keeps a copy of. It carries an identifier that the phone may choose when it creates
# the record offline (sending it twice then updates it instead of creating a second one). Deleting it leaves a
# Deletion behind, so that the user's other devices delete their copy on their next sync.
module Synced
  extend ActiveSupport::Concern

  UUID_FORMAT = /\A[0-9a-f]{8}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{12}\z/

  included do
    before_validation { self.uuid = uuid.to_s.downcase.presence || SecureRandom.uuid }
    validates :uuid, format: { with: UUID_FORMAT }, uniqueness: true
    after_destroy :record_deletion
  end

  private

  # Nothing to tell when the whole account goes
  def record_deletion
    return if destroyed_by_association&.active_record == User

    Deletion.create!(user_id: user_id, record_type: self.class.name, uuid: uuid, deleted_at: Time.current)
  end
end
