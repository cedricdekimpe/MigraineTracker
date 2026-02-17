# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
Rails.application.config.assets.paths << Rails.root.join("app/assets/builds")

# Add RailsAdmin asset paths
if defined?(RailsAdmin)
  Rails.application.config.assets.paths << RailsAdmin::Engine.root.join("app/assets/stylesheets")
  Rails.application.config.assets.paths << RailsAdmin::Engine.root.join("vendor/assets/stylesheets")
  Rails.application.config.assets.paths << RailsAdmin::Engine.root.join("src")
end

# Precompile additional assets.
Rails.application.config.assets.precompile += %w[
	application.css
	tailwind.css
	rails_admin.css
	rails_admin.js
]
