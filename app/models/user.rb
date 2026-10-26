class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :episodes, dependent: :destroy
  has_many :medications, dependent: :destroy
  has_many :triggers, dependent: :destroy
  has_many :period_days, dependent: :destroy
  has_many :treatment_periods, dependent: :destroy
  has_many :daily_checks, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy

  after_create :seed_default_triggers

  HEALTH_DATA_CONSENT_VERSION = "2026-10-23".freeze
  HEALTH_DATA_CONSENT_TEXT = "I consent to the storage and processing of my health data (migraine journal, treatments, daily check-ins and, if I turn it on, my cycle) so Migraine Tracker can provide the service.".freeze

  attr_accessor :health_data_consent

  validates :health_data_consent_given_at, presence: true, on: :create
  validates :health_data_consent_version, presence: true, on: :create
  validate :health_data_consent_presence, on: :create

  before_validation :capture_health_data_consent, on: :create

  # The daily check-in reminder: a time of the day, every half hour, or nothing (off, the default)
  DAILY_REMINDER_TIMES = (12..47).map { |half| format("%02d:%02d", half / 2, (half % 2) * 30) }.freeze
  DEFAULT_DAILY_REMINDER_AT = "20:00".freeze

  validates :daily_reminder_at, inclusion: { in: DAILY_REMINDER_TIMES }, allow_nil: true
  validate :time_zone_exists

  def daily_reminder?
    daily_reminder_at.present?
  end

  # When the reminder is due on a given day, in the person's own time zone
  def daily_reminder_due_at(date)
    hour, minute = daily_reminder_at.split(":").map(&:to_i)
    ActiveSupport::TimeZone[time_zone].local(date.year, date.month, date.day, hour, minute)
  end

  private

  def seed_default_triggers
    Trigger.seed_defaults_for(self)
  end

  def time_zone_exists
    errors.add(:time_zone, :invalid) unless ActiveSupport::TimeZone[time_zone.to_s]
  end

  def health_data_consent_presence
    return if ActiveModel::Type::Boolean.new.cast(health_data_consent)

    errors.add(:health_data_consent, :accepted, message: "You must consent to store your health data before continuing.")
  end

  def capture_health_data_consent
    return unless ActiveModel::Type::Boolean.new.cast(health_data_consent)

    self.health_data_consent_given_at ||= Time.current
    self.health_data_consent_version ||= HEALTH_DATA_CONSENT_VERSION
    self.health_data_consent_text ||= HEALTH_DATA_CONSENT_TEXT
  end
end
