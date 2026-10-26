# Runs every few minutes (config/recurring.yml) and sends the notifications that are due: the daily
# check-in reminders and "Still going?"
class NotificationsJob < ApplicationJob
  queue_as :default

  def perform
    DailyReminders.new.call
    OngoingChecks.new.call
  end
end
