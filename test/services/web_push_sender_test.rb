require "test_helper"

class WebPushSenderTest < ActiveSupport::TestCase
  setup do
    @subscription = users(:one).push_subscriptions.create!(endpoint: "https://fcm.googleapis.com/fcm/send/one", p256dh: "key", auth: "secret")
    @keys = WebPush.generate_key
  end

  teardown do
    ENV.delete("VAPID_PUBLIC_KEY")
    ENV.delete("VAPID_PRIVATE_KEY")
    restore_payload_send
  end

  def with_keys
    ENV["VAPID_PUBLIC_KEY"] = @keys.public_key
    ENV["VAPID_PRIVATE_KEY"] = @keys.private_key
  end

  # Replaces the call to the push service for one test
  def fake_payload_send(&block)
    @original = WebPush.method(:payload_send)
    WebPush.define_singleton_method(:payload_send, &block)
  end

  def restore_payload_send
    original = @original
    WebPush.define_singleton_method(:payload_send, original) if original
  end

  def deliver
    WebPushSender.new.deliver(@subscription, title: "Bilan du jour", body: "Texte", url: "/fr/check", tag: "daily-check")
  end

  test "sends nothing without keys" do
    assert_not WebPushSender.enabled?
    assert_not deliver
  end

  test "sends the message to the device's push service, signed with the keys" do
    with_keys
    received = nil
    fake_payload_send { |**options| received = options }

    assert deliver
    assert_equal "https://fcm.googleapis.com/fcm/send/one", received[:endpoint]
    assert_equal({ "title" => "Bilan du jour", "body" => "Texte", "url" => "/fr/check", "tag" => "daily-check" }, JSON.parse(received[:message]))
    assert_equal @keys.public_key, received[:vapid][:public_key]
  end

  test "a device that no longer accepts notifications is forgotten" do
    with_keys
    response = Struct.new(:body, :code).new("gone", "410")
    fake_payload_send { |**| raise WebPush::ExpiredSubscription.new(response, "push.example.com") }

    assert_not deliver
    assert_not PushSubscription.exists?(@subscription.id)
  end

  test "a push service that fails keeps the device" do
    with_keys
    fake_payload_send { |**| raise Errno::ECONNREFUSED }

    assert_not deliver
    assert PushSubscription.exists?(@subscription.id)
  end
end
