# One headache-type event: pain (migraine or plain headache), an aura, or both.
# An aura can precede a migraine or occur alone, so the two are independent fields.
class Episode < ApplicationRecord
  PAIN_KINDS = %w[migraine headache].freeze
  MAX_DURATION_MINUTES = 72 * 60

  belongs_to :user
  has_many :medication_intakes, -> { order(:id) }, dependent: :destroy, inverse_of: :episode
  has_many :medications, through: :medication_intakes
  has_many :episode_triggers, dependent: :destroy
  has_many :triggers, through: :episode_triggers

  accepts_nested_attributes_for :medication_intakes, allow_destroy: true,
    reject_if: ->(attributes) { attributes["id"].blank? && attributes["medication_id"].blank? }

  before_validation :normalize_pain

  validates :occurred_on, presence: true
  validates :pain_kind, inclusion: { in: PAIN_KINDS }, allow_nil: true
  validates :intensity, presence: true, if: :pain?
  validates :intensity, numericality: { only_integer: true, in: 1..10 }, allow_nil: true
  validates :duration_minutes, numericality: { only_integer: true, in: 1..MAX_DURATION_MINUTES }, allow_nil: true
  validate :aura_or_pain
  validate :triggers_belong_to_user

  scope :for_month, ->(date) { where(occurred_on: date.beginning_of_month..date.end_of_month) }
  scope :chronological, -> { order(:occurred_on, :started_time, :id) }

  def pain?
    pain_kind.present?
  end

  # Compact label for calendars: M (migraine), H (headache), A (aura alone), MA / HA (pain preceded by aura).
  def code
    "#{pain_kind&.first&.upcase}#{'A' if aura?}"
  end

  private

  def normalize_pain
    self.pain_kind = pain_kind.presence
    self.intensity = nil unless pain?
  end

  def aura_or_pain
    errors.add(:base, :aura_or_pain) unless aura? || pain?
  end

  def triggers_belong_to_user
    return if triggers.all? { |trigger| trigger.user_id == user_id }

    errors.add(:triggers, :invalid)
  end
end
