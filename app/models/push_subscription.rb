# One browser on one device that accepted notifications (web push). The keys come from the browser and
# only serve to encrypt the message for it.
class PushSubscription < ApplicationRecord
  # The server posts to the endpoint: only the push services of the browsers, never an address of the
  # visitor's choosing (which could point at a machine inside the server's network)
  PUSH_SERVICE_HOSTS = %w[fcm.googleapis.com updates.push.services.mozilla.com push.apple.com notify.windows.com].freeze

  belongs_to :user

  validates :endpoint, presence: true, uniqueness: true, length: { maximum: 1000 }, format: { with: %r{\Ahttps://\S+\z} }
  validates :p256dh, :auth, presence: true, length: { maximum: 200 }
  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }
  validate :endpoint_of_a_push_service

  private

  def endpoint_of_a_push_service
    host = URI.parse(endpoint.to_s).host.to_s.downcase
    errors.add(:endpoint, :invalid) unless PUSH_SERVICE_HOSTS.any? { |allowed| host == allowed || host.end_with?(".#{allowed}") }
  rescue URI::InvalidURIError
    errors.add(:endpoint, :invalid)
  end
end
