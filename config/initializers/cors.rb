# frozen_string_literal: true

# Configure CORS for API access from mobile apps and other clients
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # In production, you should restrict this to specific origins
    # For mobile apps, you typically need to allow all origins
    origins '*'

    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ['Authorization'],
      max_age: 600
  end
end
