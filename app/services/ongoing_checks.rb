# "Still going?": one notification for an attack started with "I have a headache now" and still open
# 12 hours later, for those who turned it on. Tapping it opens the attack, where the end time can be given.
class OngoingChecks
  AFTER = 12.hours

  def initialize(sender: WebPushSender.new)
    @sender = sender
  end

  def call(now: Time.current)
    due_episodes(now).count { |episode| ask(episode, now) }
  end

  private

  def due_episodes(now)
    Episode.ongoing.where(ongoing_checked_at: nil).where.not(started_time: nil)
           .joins(:user).where(users: { ongoing_check: true }).where(user_id: PushSubscription.select(:user_id))
           .includes(user: :push_subscriptions).select { |episode| episode.started_at <= now - AFTER }
  end

  def ask(episode, now)
    # Marked first: a second run while this one sends must not ask twice
    episode.update_columns(ongoing_checked_at: now)

    episode.user.push_subscriptions.to_a.count do |subscription|
      I18n.with_locale(subscription.locale) do
        @sender.deliver(subscription, title: I18n.t("reminders.still_going.title"), body: I18n.t("reminders.still_going.body"),
                        url: Rails.application.routes.url_helpers.now_path(locale: subscription.locale), tag: "still-going")
      end
    end.positive?
  end
end
