# The daily check-in reminder: at most one a day, at the time each person chose, in their own time zone,
# and only if the check-in of the day is still empty. The text says nothing about health: it shows on a
# locked screen. If the server was down at the chosen time, the reminder is dropped rather than sent late.
class DailyReminders
  LATE_LIMIT = 2.hours

  def initialize(sender: WebPushSender.new)
    @sender = sender
  end

  def call(now: Time.current)
    due_users(now).count { |user| remind(user, now.in_time_zone(user.time_zone)) }
  end

  private

  def due_users(now)
    User.where.not(daily_reminder_at: nil).where(id: PushSubscription.select(:user_id)).select do |user|
      local = now.in_time_zone(user.time_zone)
      due = user.daily_reminder_due_at(local.to_date)
      local >= due && local < due + LATE_LIMIT && user.daily_reminder_sent_on != local.to_date
    end
  end

  def remind(user, local)
    # Marked first: a second run while this one sends must not remind twice
    user.update_columns(daily_reminder_sent_on: local.to_date)
    return false if user.daily_checks.exists?(date: local.to_date)

    user.push_subscriptions.to_a.count do |subscription|
      I18n.with_locale(subscription.locale) do
        @sender.deliver(subscription, title: I18n.t("reminders.daily.title"), body: I18n.t("reminders.daily.body"),
                        url: Rails.application.routes.url_helpers.check_path(locale: subscription.locale), tag: "daily-check")
      end
    end.positive?
  end
end
