# A stretch of time during which a preventive medication was taken (open-ended while it still is).
class TreatmentPeriod < ApplicationRecord
  STOP_REASONS = %w[ineffective not_tolerated planned other].freeze

  belongs_to :user
  belongs_to :medication

  before_validation { self.dose = dose.to_s.strip.presence; self.stop_reason = stop_reason.presence }

  validates :started_on, presence: true
  validates :dose, length: { maximum: 50 }
  validates :stop_reason, inclusion: { in: STOP_REASONS }, allow_nil: true
  validate :ends_after_start
  validate :stop_reason_needs_an_end
  validate :medication_is_a_preventive_of_the_user
  validate :no_overlap

  scope :chronological, -> { order(:started_on, :id) }
  scope :current, -> { where(ended_on: nil) }

  def current?
    ended_on.nil?
  end

  # Whole days the treatment lasted so far (to the end date, or today while it goes on).
  def days(today: Date.current)
    ((ended_on || today) - started_on).to_i + 1
  end

  private

  def ends_after_start
    errors.add(:ended_on, :before_start) if ended_on && started_on && ended_on < started_on
  end

  def stop_reason_needs_an_end
    errors.add(:stop_reason, :needs_end) if stop_reason && ended_on.nil?
  end

  def medication_is_a_preventive_of_the_user
    return if medication.nil?

    errors.add(:medication, :not_preventive) unless medication.kind == "preventive"
    errors.add(:medication, :invalid) if user_id && medication.user_id != user_id
  end

  # Two periods of the same medication cannot overlap: it was taken, or it was not.
  def no_overlap
    return if medication.nil? || started_on.nil?

    others = medication.treatment_periods.where.not(id: id)
    last = ended_on || Date.new(9999, 12, 31)
    clash = others.where("started_on <= ?", last).where("ended_on IS NULL OR ended_on >= ?", started_on)
    errors.add(:base, :overlap) if clash.exists?
  end
end
