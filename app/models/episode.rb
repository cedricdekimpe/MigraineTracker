# One headache-type event: pain (migraine or plain headache), an aura, or both.
# An aura can precede a migraine or occur alone, so the two are independent fields.
class Episode < ApplicationRecord
  PAIN_KINDS = %w[migraine headache].freeze
  # An attack longer than 72 h is, by definition, a status migrainosus (ICHD-3 1.4.1): worth telling a
  # doctor. It is recorded as it is, up to a week, instead of being cut.
  LONG_ATTACK_MINUTES = 72 * 60
  MAX_DURATION_MINUTES = 7 * 24 * 60

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
  # Started with "I have a headache now" and not closed yet (older than a week = forgotten, ignored).
  scope :ongoing, -> { where(ongoing: true, occurred_on: 7.days.ago.to_date..) }
  scope :chronological, -> { order(:occurred_on, :started_time, :id) }

  # Start instant, when a start time is known.
  def started_at
    return unless started_time

    Time.zone.local(occurred_on.year, occurred_on.month, occurred_on.day, started_time.hour, started_time.min)
  end

  def pain?
    pain_kind.present?
  end

  # Longer than 72 h, whether the duration was entered or is still running.
  def long_attack?(now: Time.current)
    minutes = duration_minutes || (ongoing? && started_at ? (now - started_at) / 60 : nil)
    minutes.present? && minutes > LONG_ATTACK_MINUTES
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
