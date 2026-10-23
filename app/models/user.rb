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

  after_create :seed_default_triggers

  HEALTH_DATA_CONSENT_VERSION = "2026-10-23".freeze
  HEALTH_DATA_CONSENT_TEXT = "I consent to the storage and processing of my health data (migraine journal, treatments, daily check-ins and, if I turn it on, my cycle) so Migraine Tracker can provide the service.".freeze

  attr_accessor :health_data_consent

  validates :health_data_consent_given_at, presence: true, on: :create
  validates :health_data_consent_version, presence: true, on: :create
  validate :health_data_consent_presence, on: :create

  before_validation :capture_health_data_consent, on: :create

  private

  def seed_default_triggers
    Trigger.seed_defaults_for(self)
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
