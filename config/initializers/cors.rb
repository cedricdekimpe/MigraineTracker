# frozen_string_literal: true

# Configure CORS for API access from mobile apps and other clients
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    allowed_origins = ENV.fetch("CORS_ALLOWED_ORIGINS", "https://migraine-tracker.eu").split(",").map(&:strip)
    origins(*allowed_origins)

    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ['Authorization'],
      max_age: 600
  end
end
