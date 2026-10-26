require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Don't use sassc compressor to avoid issues with modern CSS syntax in Tailwind
  config.assets.css_compressor = nil

  # Use precompiled assets instead of compiling on the fly
  config.assets.compile = false

  # Enable serving of static files (assets) from the public directory
  # With Kamal, assets are served from /rails/public/assets, so we need to enable this
  config.public_file_server.enabled = true

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # Behind a TLS proxy this stays on. FORCE_SSL=false is for trying the app over plain http on one's own machine.
  config.force_ssl = ENV.fetch("FORCE_SSL", "true") != "false"
  # The proxy's health check calls /up in plain HTTP: it must get a 200, not a redirect to HTTPS.
  config.ssl_options = {
    hsts: { expires: 1.year, subdomains: true, preload: true },
    redirect: { exclude: ->(request) { request.path == "/up" } }
  }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  config.action_dispatch.cookies_same_site_protection = :strict

  config.action_dispatch.default_headers.merge!(
    "X-Frame-Options" => "DENY",
    "X-Content-Type-Options" => "nosniff",
    "Referrer-Policy" => "strict-origin-when-cross-origin",
    "Permissions-Policy" => "geolocation=(), microphone=(), camera=()"
  )

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Links in mails point to the public address
  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "localhost"), protocol: ENV.fetch("FORCE_SSL", "true") == "false" ? "http" : "https" }

  # Mail goes out through the SMTP mailbox (Infomaniak) whose password is given to the container.
  # Without it nothing is sent (a password reset then shows an error instead of failing silently).
  if ENV["SMTP_PASSWORD"].present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.smtp_settings = {
      address: ENV.fetch("SMTP_HOST", "mail.infomaniak.com"),
      port: ENV.fetch("SMTP_PORT", 587).to_i,
      user_name: ENV["SMTP_USER"],
      password: ENV["SMTP_PASSWORD"],
      authentication: :plain,
      enable_starttls_auto: true
    }
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
