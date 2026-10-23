# A day of menstrual bleeding (the "0" row of the paper calendar). Recorded for the day itself so that
# days without any headache count too.
class PeriodDay < ApplicationRecord
  belongs_to :user

  validates :date, presence: true, uniqueness: { scope: :user_id }

  scope :between, ->(range) { where(date: range) }
end
