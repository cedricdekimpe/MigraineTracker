# frozen_string_literal: true

# A synced record that no longer exists (see Synced). Kept so that the user's other devices learn about it.
class Deletion < ApplicationRecord
  TYPES = %w[Episode PeriodDay DailyCheck].freeze

  belongs_to :user

  validates :record_type, inclusion: { in: TYPES }
end
