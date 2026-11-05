# One dose of a medication taken for an episode.
class MedicationIntake < ApplicationRecord
  EFFECTS = %w[none partial good].freeze

  # Intakes travel inside their episode for the mobile app: changing one changes the episode
  belongs_to :episode, inverse_of: :medication_intakes, touch: true
  belongs_to :medication

  before_validation { self.uuid = uuid.to_s.downcase.presence || SecureRandom.uuid }
  before_validation { self.dose = dose.to_s.strip.presence; self.effect = effect.presence }

  validates :uuid, format: { with: Synced::UUID_FORMAT }, uniqueness: true
  validates :dose, length: { maximum: 50 }
  validates :effect, inclusion: { in: EFFECTS }, allow_nil: true
  validate :medication_belongs_to_episode_user

  private

  def medication_belongs_to_episode_user
    return if medication.nil? || episode.nil? || medication.user_id == episode.user_id

    errors.add(:medication, :invalid)
  end
end
