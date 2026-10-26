# Sends one notification to one device through its browser's push service (Google, Apple, Mozilla...).
# The message is encrypted for the device: the push service only sees that a message passes. A device that
# no longer accepts notifications (app removed, permission withdrawn) loses its subscription.
#
# The keys identify this server to the push services (VAPID). Without them nothing is ever sent and the
# reminder settings do not show. Generate them once with:
#   bin/rails runner 'k = WebPush.generate_key; puts "VAPID_PUBLIC_KEY=#{k.public_key}", "VAPID_PRIVATE_KEY=#{k.private_key}"'
class WebPushSender
  def self.enabled?
    public_key.present? && ENV["VAPID_PRIVATE_KEY"].present?
  end

  def self.public_key
    ENV["VAPID_PUBLIC_KEY"]
  end

  # Whoever runs this copy, for the push service to reach if something goes wrong
  def self.subject
    contact = Instance.contact_email || ENV["MAIL_FROM"].presence
    contact ? "mailto:#{contact}" : "https://#{ENV.fetch('APP_HOST', 'localhost')}"
  end

  # Returns true when the push service took the message
  def deliver(subscription, title:, body:, url:, tag:)
    return false unless self.class.enabled?

    WebPush.payload_send(
      message: { title: title, body: body, url: url, tag: tag }.to_json,
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh,
      auth: subscription.auth,
      vapid: { subject: self.class.subject, public_key: self.class.public_key, private_key: ENV["VAPID_PRIVATE_KEY"] },
      ttl: 4.hours.to_i,
      urgency: "normal"
    )
    true
  # Unauthorized: the subscription was made with other keys (they changed), it can never work again
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription, WebPush::Unauthorized
    subscription.destroy
    false
  rescue WebPush::Error, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, SocketError => error
    Rails.logger.warn("Web push failed (#{error.class})")
    false
  end
end
