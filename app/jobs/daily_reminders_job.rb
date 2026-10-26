# Runs every few minutes (config/recurring.yml) and sends the daily check-in reminders that are due
class DailyRemindersJob < ApplicationJob
  queue_as :default

  def perform
    DailyReminders.new.call
  end
end
