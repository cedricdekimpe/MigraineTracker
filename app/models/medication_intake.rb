# One dose of a medication taken for an episode.
class MedicationIntake < ApplicationRecord
  EFFECTS = %w[none partial good].freeze

  belongs_to :episode, inverse_of: :medication_intakes
  belongs_to :medication

  before_validation { self.dose = dose.to_s.strip.presence; self.effect = effect.presence }

  validates :dose, length: { maximum: 50 }
  validates :effect, inclusion: { in: EFFECTS }, allow_nil: true
  validate :medication_belongs_to_episode_user

  # taken_time is a time of day: the moment it points to is the one nearest to the start of the attack (within 12 hours
  # either way). After midnight in an attack that began in the evening it is the next day; shortly before an attack
  # that began just after midnight it is the evening before.
  def taken_at
    return unless taken_time && episode

    day = episode.occurred_on
    at = Time.zone.local(day.year, day.month, day.day, taken_time.hour, taken_time.min)
    started = episode.started_at
    if started
      at += 1.day if started - at > 12.hours
      at -= 1.day if at - started > 12.hours
    end
    at
  end

  private

  def medication_belongs_to_episode_user
    return if medication.nil? || episode.nil? || medication.user_id == episode.user_id

    errors.add(:medication, :invalid)
  end
end
