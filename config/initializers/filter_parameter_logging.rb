# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :health_data_consent,
  # Health data never reaches the logs. Whole groups are filtered (a field added to them later is
  # covered), plus the loose parameters of the one-tap screens and of the import.
  :episode, :daily_check, :treatment_period, :medication, :trigger, :period, :file,
  :pain_kind, :aura, :intensity, :name, :kind, :effect, :dose, :date, :occurred_on
]
