require "test_helper"

class RemindersTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
    ENV["VAPID_PUBLIC_KEY"] = "BPublicKey"
    ENV["VAPID_PRIVATE_KEY"] = "private"
  end

  teardown do
    ENV.delete("VAPID_PUBLIC_KEY")
    ENV.delete("VAPID_PRIVATE_KEY")
  end

  def subscription_params(endpoint = "https://fcm.googleapis.com/fcm/send/abc")
    { subscription: { endpoint: endpoint, keys: { p256dh: "key", auth: "secret" } } }
  end

  test "the account shows the reminder, off by default" do
    get account_profile_path(locale: "fr")
    assert_select "[data-controller=reminder]"
    assert_select "input#reminder_enabled:not([checked])"
    assert_select "select#reminder_time option[selected]", text: "20:00"
  end

  test "no reminder setting when this copy has no push keys" do
    ENV.delete("VAPID_PUBLIC_KEY")
    get account_profile_path(locale: "fr")
    assert_select "[data-controller=reminder]", count: 0
  end

  test "turning it on keeps the time and the time zone" do
    patch account_reminder_path(locale: "fr"), params: { enabled: "1", time: "21:30", time_zone: "Europe/Paris" }
    assert_redirected_to account_profile_path
    @user.reload
    assert_equal "21:30", @user.daily_reminder_at
    assert_equal "Europe/Paris", @user.time_zone
  end

  test "an unknown time or time zone falls back" do
    patch account_reminder_path(locale: "fr"), params: { enabled: "1", time: "25:00", time_zone: "Mars/Olympus" }
    @user.reload
    assert_equal "20:00", @user.daily_reminder_at
    assert_equal "Europe/Brussels", @user.time_zone
  end

  test "turning it off forgets every device" do
    @user.update!(daily_reminder_at: "20:00")
    @user.push_subscriptions.create!(endpoint: "https://fcm.googleapis.com/fcm/send/abc", p256dh: "key", auth: "secret")

    patch account_reminder_path(locale: "fr"), params: { enabled: "0" }
    assert_nil @user.reload.daily_reminder_at
    assert_empty @user.push_subscriptions
  end

  test "a device that accepts notifications is kept once, in the page language" do
    2.times { post push_subscriptions_path(locale: "en"), params: subscription_params, as: :json }
    assert_response :created
    subscription = @user.push_subscriptions.sole
    assert_equal "en", subscription.locale
  end

  test "a device moves to the account signed in on it" do
    users(:two).push_subscriptions.create!(endpoint: "https://fcm.googleapis.com/fcm/send/abc", p256dh: "old", auth: "old")
    post push_subscriptions_path(locale: "fr"), params: subscription_params, as: :json
    assert_equal @user, PushSubscription.find_by(endpoint: "https://fcm.googleapis.com/fcm/send/abc").user
  end

  test "only the https push services of the browsers" do
    [ "http://fcm.googleapis.com/fcm/send/x", "https://evil.example.com/x", "https://fcm.googleapis.com.evil.example/x",
      "https://192.168.1.1/x" ].each do |endpoint|
      post push_subscriptions_path(locale: "fr"), params: subscription_params(endpoint), as: :json
      assert_response :unprocessable_entity, endpoint
    end
    post push_subscriptions_path(locale: "fr"), params: subscription_params("https://web.push.apple.com/QGuQyavXut"), as: :json
    assert_response :created
  end

  test "needs to be signed in" do
    sign_out @user
    post push_subscriptions_path(locale: "fr"), params: subscription_params, as: :json
    assert_response :unauthorized
    assert_empty PushSubscription.all
  end
end
