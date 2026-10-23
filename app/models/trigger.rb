# A user-defined factor that may provoke an episode (stress, lack of sleep, ...).
class Trigger < ApplicationRecord
  # The ones the evidence points to (stress and its let-down, sleep, fasting, caffeine, weather, alcohol
  # by report); the daily check-in covers sleep, stress, meals and caffeine day by day.
  DEFAULT_KEYS = %w[stress lack_of_sleep alcohol skipped_meal caffeine weather].freeze

  belongs_to :user
  has_many :episode_triggers, dependent: :destroy
  has_many :episodes, through: :episode_triggers

  before_validation { self.name = name.to_s.strip }

  validates :name, presence: true, length: { maximum: 50 }, uniqueness: { scope: :user_id, case_sensitive: false }

  scope :alphabetical, -> { order(Arel.sql("lower(name)")) }

  # Creates the default triggers in the current locale (called at sign-up).
  def self.seed_defaults_for(user)
    DEFAULT_KEYS.each { |key| user.triggers.find_or_create_by(name: I18n.t("triggers.defaults.#{key}")) }
  end
end
