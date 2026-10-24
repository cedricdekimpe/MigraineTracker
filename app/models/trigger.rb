# A user-defined factor that may provoke an episode (stress, lack of sleep, ...).
class Trigger < ApplicationRecord
  # The ones the evidence points to (stress and its let-down, sleep, fasting, caffeine, weather, alcohol
  # by report); the daily check-in covers sleep, stress, meals and caffeine day by day.
  DEFAULT_KEYS = %w[stress lack_of_sleep alcohol skipped_meal caffeine weather].freeze
  # Offered as one-tap examples on the triggers page, with a few more that people often report
  EXAMPLE_KEYS = (DEFAULT_KEYS + %w[screens strong_smells bright_light noise]).freeze

  belongs_to :user
  has_many :episode_triggers, dependent: :destroy
  has_many :episodes, through: :episode_triggers

  before_validation { self.name = name.to_s.strip }
  # A typed "Manque de sommeil" is the default "lack_of_sleep", whatever the language it was stored in
  before_validation(on: :create) { self.key ||= Trigger.default_key_for(name) }

  validates :name, presence: true, length: { maximum: 50 }, uniqueness: { scope: :user_id, case_sensitive: false }
  validate :one_of_each_default

  scope :alphabetical, -> { order(Arel.sql("lower(name)")) }

  # Creates the default triggers (called at sign-up). They keep their key and show in the
  # language of the interface, whatever the language of the sign-up.
  def self.seed_defaults_for(user)
    DEFAULT_KEYS.each do |key|
      next if user.triggers.exists?(key: key)

      user.triggers.find_or_create_by(name: I18n.t("triggers.defaults.#{key}")) { |trigger| trigger.key = key }
    end
  end

  # The default a name stands for, in any language of the interface, or nil.
  def self.default_key_for(name)
    clean = name.to_s.strip.downcase
    I18n.available_locales.each do |locale|
      key = DEFAULT_KEYS.find { |candidate| I18n.t("triggers.defaults.#{candidate}", locale: locale).downcase == clean }
      return key if key
    end
    nil
  end

  # The name to show: the translation for a default one, the person's own word otherwise.
  def display_name
    key.present? ? I18n.t("triggers.defaults.#{key}", default: name) : name
  end

  private

  def one_of_each_default
    return if key.nil? || user.nil?

    errors.add(:name, :taken) if user.triggers.where.not(id: id).exists?(key: key)
  end
end
