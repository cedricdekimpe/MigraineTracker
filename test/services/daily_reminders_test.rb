require "test_helper"

class DailyRemindersTest < ActiveSupport::TestCase
  # Keeps what would have been sent instead of calling a push service
  class FakeSender
    attr_reader :sent

    def initialize
      @sent = []
    end

    def deliver(subscription, **message)
      @sent << message.merge(endpoint: subscription.endpoint)
      true
    end
  end

  setup do
    @user = users(:one)
    @user.update!(daily_reminder_at: "20:00", time_zone: "Europe/Brussels")
    @subscription = @user.push_subscriptions.create!(endpoint: "https://fcm.googleapis.com/fcm/send/one", p256dh: "key", auth: "secret", locale: "fr")
    @sender = FakeSender.new
    @evening = Time.find_zone("Europe/Brussels").local(2026, 10, 20, 20, 5)
  end

  def run_at(time)
    DailyReminders.new(sender: @sender).call(now: time)
  end

  test "sends the reminder at the chosen time, in the language of the device, without health data" do
    assert_equal 1, run_at(@evening)
    message = @sender.sent.sole
    assert_equal "Bilan du jour", message[:title]
    assert_equal "/fr/check", message[:url]
    assert_equal "daily-check", message[:tag]
    assert_equal Date.new(2026, 10, 20), @user.reload.daily_reminder_sent_on
  end

  test "nothing before the time, nor more than two hours late" do
    run_at(@evening - 10.minutes)
    run_at(@evening + 2.hours)
    assert_empty @sender.sent
  end

  test "at most one a day" do
    run_at(@evening)
    run_at(@evening + 5.minutes)
    assert_equal 1, @sender.sent.size

    run_at(@evening + 1.day)
    assert_equal 2, @sender.sent.size
  end

  test "nothing when the check-in of the day is already filled in" do
    @user.daily_checks.create!(date: Date.new(2026, 10, 20), sleep: "good")
    run_at(@evening)
    assert_empty @sender.sent
  end

  test "follows the person's time zone" do
    @user.update!(time_zone: "America/New_York")
    run_at(@evening)
    assert_empty @sender.sent

    run_at(Time.find_zone("America/New_York").local(2026, 10, 20, 20, 0))
    assert_equal 1, @sender.sent.size
  end

  test "nothing when the reminder is off or no device accepted notifications" do
    @user.update!(daily_reminder_at: nil)
    run_at(@evening)

    @user.update!(daily_reminder_at: "20:00")
    @subscription.destroy
    run_at(@evening)
    assert_empty @sender.sent
  end

  test "every device of the person gets it, each in its own language" do
    @user.push_subscriptions.create!(endpoint: "https://fcm.googleapis.com/fcm/send/two", p256dh: "key", auth: "secret", locale: "en")
    run_at(@evening)
    assert_equal [ "Bilan du jour", "Daily check-in" ], @sender.sent.map { |message| message[:title] }.sort
  end
end
