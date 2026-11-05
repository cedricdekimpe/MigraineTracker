# frozen_string_literal: true

# /.well-known/migraine-tracker.json: what the mobile app reads before signing in to a server, to show who runs
# it and to check that the server is recent enough. It says nothing about the accounts.
class WellKnownController < ActionController::API
  def instance
    render json: {
      name: "Migraine Tracker",
      version: MyMigraineManager::VERSION,
      api: { versions: [ "v1" ], url: "#{request.base_url}/api/v1" },
      app: { minimum_version: MyMigraineManager::MINIMUM_APP_VERSION },
      official: Instance.official?,
      operator: { name: Instance.operator_name, contact: Instance.contact_email },
      signups_open: Instance.signups_open?,
      locales: I18n.available_locales.map(&:to_s),
      privacy_url: I18n.available_locales.to_h { |locale| [ locale, privacy_url(locale: locale) ] },
      path_configuration: { android: "#{request.base_url}/configurations/android_v1.json" }
    }
  end
end
