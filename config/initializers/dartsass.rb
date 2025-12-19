# Configure dartsass-rails to only build rails_admin.css
Rails.application.config.dartsass.builds = {
  "rails_admin.scss" => "rails_admin.css"
}
