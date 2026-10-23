ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  def consent_attrs
    {
      health_data_consent: true,
      health_data_consent_given_at: Time.current,
      health_data_consent_version: User::HEALTH_DATA_CONSENT_VERSION,
      health_data_consent_text: User::HEALTH_DATA_CONSENT_TEXT
    }
  end

  # Add more helper methods to be used by all tests here...
end
