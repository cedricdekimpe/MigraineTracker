# frozen_string_literal: true

class Rack::Attack
  # Throttle authenticated API requests by user id
  # 100 requests per minute per user
  throttle('api/authenticated', limit: 100, period: 1.minute) do |req|
    if req.path.start_with?('/api/') && req.env['warden']&.user&.id
      req.env['warden'].user.id
    end
  end

  # Throttle unauthenticated API requests by IP
  # 100 requests per minute per IP
  throttle('api/unauthenticated', limit: 100, period: 1.minute) do |req|
    if req.path.start_with?('/api/')
      req.ip
    end
  end

  # Stricter throttle for authentication endpoints
  # 10 requests per minute per IP to prevent brute force
  throttle('api/auth', limit: 10, period: 1.minute) do |req|
    if req.path.start_with?('/api/v1/auth/login') || 
       req.path.start_with?('/api/v1/auth/register')
      req.ip
    end
  end

  # Block suspicious requests
  blocklist('block bad actors') do |req|
    # Block requests that appear to be scanning for vulnerabilities
    req.path.include?('.php') ||
    req.path.include?('wp-') ||
    req.path.include?('wordpress')
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |request|
    match_data = request.env['rack.attack.match_data']
    now = Time.current

    headers = {
      'Content-Type' => 'application/vnd.api+json',
      'Retry-After' => (match_data[:period] - (now.to_i % match_data[:period])).to_s,
      'X-RateLimit-Limit' => match_data[:limit].to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (now + (match_data[:period] - (now.to_i % match_data[:period]))).to_i.to_s
    }

    body = {
      errors: [{
        status: '429',
        title: 'Too Many Requests',
        detail: "Rate limit exceeded. Retry after #{headers['Retry-After']} seconds."
      }]
    }.to_json

    [429, headers, [body]]
  end

  # Custom response for blocked requests
  self.blocklisted_responder = lambda do |request|
    headers = { 'Content-Type' => 'application/vnd.api+json' }
    body = {
      errors: [{
        status: '403',
        title: 'Forbidden',
        detail: 'Your request has been blocked.'
      }]
    }.to_json

    [403, headers, [body]]
  end
end

# Enable Rack::Attack
Rails.application.config.middleware.use Rack::Attack
