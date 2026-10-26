# frozen_string_literal: true

class Rack::Attack
  # --- Web (Devise) endpoints -------------------------------------------------
  # Paths may carry a locale prefix: /users/sign_in or /fr/users/sign_in.
  WEB_USERS_PATH = %r{\A(?:/(?:en|fr))?/users(?<rest>/[a-z_]+)?/?\z}

  # Normalised email submitted in a Devise form (user[email]), if any.
  def self.submitted_email(req)
    user = req.params["user"]
    email = user["email"] if user.is_a?(Hash)
    email.to_s.strip.downcase.presence if email.is_a?(String)
  rescue StandardError
    nil # unparsable body: the app itself will reject it; the IP throttles still apply
  end

  def self.web_users_action(req)
    match = WEB_USERS_PATH.match(req.path)
    return unless match

    [ req.request_method, match[:rest].to_s ]
  end

  # Brute force on the sign-in form: per IP, and per targeted account (any IP).
  throttle("web/logins/ip", limit: 10, period: 1.minute) do |req|
    req.ip if web_users_action(req) == [ "POST", "/sign_in" ]
  end

  throttle("web/logins/email", limit: 8, period: 10.minutes) do |req|
    submitted_email(req) if web_users_action(req) == [ "POST", "/sign_in" ]
  end

  # Password reset requests (also prevents mail bombing a given address).
  throttle("web/password_resets/ip", limit: 5, period: 1.hour) do |req|
    req.ip if web_users_action(req) == [ "POST", "/password" ]
  end

  throttle("web/password_resets/email", limit: 3, period: 1.hour) do |req|
    submitted_email(req) if web_users_action(req) == [ "POST", "/password" ]
  end

  # Mass account creation.
  throttle("web/signups/ip", limit: 10, period: 1.hour) do |req|
    req.ip if web_users_action(req) == [ "POST", "" ]
  end

  # Account update / deletion check the current password: stop password guessing there too.
  throttle("web/account_changes/ip", limit: 10, period: 10.minutes) do |req|
    req.ip if %w[PATCH PUT DELETE].include?(req.request_method) && web_users_action(req)&.last == ""
  end

  # Block suspicious requests
  blocklist("block bad actors") do |req|
    # Block requests that appear to be scanning for vulnerabilities
    req.path.include?(".php") ||
    req.path.include?("wp-") ||
    req.path.include?("wordpress")
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    retry_after = match_data[:period] - (Time.current.to_i % match_data[:period])
    minutes = (retry_after / 60.0).ceil

    body = if request.path.start_with?("/fr") || request.env["HTTP_ACCEPT_LANGUAGE"].to_s.start_with?("fr")
      "Trop de tentatives. Réessayez dans #{minutes} minute(s)."
    else
      "Too many attempts. Please try again in #{minutes} minute(s)."
    end

    [ 429, { "Content-Type" => "text/plain; charset=utf-8", "Retry-After" => retry_after.to_s }, [ body ] ]
  end

  self.blocklisted_responder = lambda do |_request|
    [ 403, { "Content-Type" => "text/plain; charset=utf-8" }, [ "Your request has been blocked." ] ]
  end
end

# Enable Rack::Attack
Rails.application.config.middleware.use Rack::Attack
