require "test_helper"

class OngoingChecksTest < ActiveSupport::TestCase
  class FakeSender
    attr_reader :sent

    def initialize
      @sent = []
    end

    def deliver(subscription, **message)
      @sent << message
      true
    end
  end

  setup do
    @user = users(:one)
    @user.update!(ongoing_check: true)
    @user.push_subscriptions.create!(endpoint: "https://fcm.googleapis.com/fcm/send/one", p256dh: "key", auth: "secret", locale: "fr")
    @start = Time.zone.local(2026, 10, 24, 9, 0)
    @episode = @user.episodes.create!(occurred_on: @start.to_date, started_time: "09:00", pain_kind: "migraine", intensity: 5, ongoing: true)
    @sender = FakeSender.new
  end

  def run_at(time)
    travel_to(time) { OngoingChecks.new(sender: @sender).call(now: time) }
  end

  test "asks once, 12 hours after the start, and opens the attack" do
    run_at(@start + 11.hours)
    assert_empty @sender.sent

    run_at(@start + 12.hours)
    run_at(@start + 13.hours)
    message = @sender.sent.sole
    assert_equal "Toujours en cours ?", message[:title]
    assert_equal "/fr/now", message[:url]
    assert @episode.reload.ongoing_checked_at
  end

  test "nothing for a closed attack, when it is off, or without a device" do
    @episode.update!(ongoing: false, duration_minutes: 60)
    run_at(@start + 13.hours)

    @episode.update!(ongoing: true, duration_minutes: nil)
    @user.update!(ongoing_check: false)
    run_at(@start + 13.hours)

    @user.update!(ongoing_check: true)
    @user.push_subscriptions.destroy_all
    run_at(@start + 13.hours)
    assert_empty @sender.sent
  end
end
