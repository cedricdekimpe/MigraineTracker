# What the day was like: sleep, stress, meals and caffeine. Any answer may be left empty.
class DailyCheck < ApplicationRecord
  SLEEPS = %w[good fragmented short].freeze
  STRESSES = %w[low medium high].freeze
  CAFFEINES = %w[none usual high].freeze

  belongs_to :user

  before_validation do
    self.sleep = sleep.presence
    self.stress = stress.presence
    self.caffeine = caffeine.presence
  end

  validates :date, presence: true, uniqueness: { scope: :user_id }, journal_date: true
  validates :sleep, inclusion: { in: SLEEPS }, allow_nil: true
  validates :stress, inclusion: { in: STRESSES }, allow_nil: true
  validates :caffeine, inclusion: { in: CAFFEINES }, allow_nil: true

  # Stress as a number to compare one day with the next
  def stress_level
    STRESSES.index(stress)
  end
end
