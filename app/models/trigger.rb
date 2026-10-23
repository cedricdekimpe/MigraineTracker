# A user-defined factor that may provoke an episode (stress, lack of sleep, ...).
class Trigger < ApplicationRecord
  DEFAULT_KEYS = %w[stress lack_of_sleep alcohol skipped_meal weather screens strong_smells].freeze

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
