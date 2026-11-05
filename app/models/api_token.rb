# frozen_string_literal: true

# One signed-in device of the mobile app. The token itself is shown once, to the app; only its digest is kept,
# so a copy of the database does not give access to the accounts. Deleting the row signs the device out.
class ApiToken < ApplicationRecord
  WEB_CODE_LIFETIME = 1.minute
  # Updating "last used" on every request would write for every request
  LAST_USED_PRECISION = 1.hour

  belongs_to :user

  validates :name, presence: true, length: { maximum: 60 }

  scope :recent_first, -> { order(Arel.sql("coalesce(last_used_at, created_at) DESC")) }

  # The new token and its plain value, which is never stored
  def self.issue(user, name:)
    value = SecureRandom.base58(32)
    [ user.api_tokens.create!(name: name.to_s.strip.first(60).presence || "Android", token_digest: digest(value)), value ]
  end

  def self.authenticate(value)
    return nil if value.blank?

    token = includes(:user).find_by(token_digest: digest(value))
    token&.used!
    token
  end

  def self.digest(value) = OpenSSL::Digest::SHA256.hexdigest(value.to_s)

  # A one-time code, valid one minute, that the app's web view exchanges for a web session
  def issue_web_code!
    value = SecureRandom.base58(24)
    update!(web_code_digest: self.class.digest(value), web_code_expires_at: WEB_CODE_LIFETIME.from_now)
    value
  end

  # The device whose code this is, once: the code is spent even when it has expired
  def self.redeem_web_code(value)
    return nil if value.blank?

    token = find_by(web_code_digest: digest(value)) or return nil
    valid = token.web_code_expires_at&.future?
    token.update!(web_code_digest: nil, web_code_expires_at: nil)
    token if valid
  end

  def used!
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < LAST_USED_PRECISION.ago
  end
end
