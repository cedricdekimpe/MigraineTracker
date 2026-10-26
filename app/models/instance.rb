# frozen_string_literal: true

# Which copy of Migraine Tracker this is. The hosted one (migraine-tracker.eu) runs with INSTANCE=official and
# carries its author's own pages and policy. Anyone else running the code is the operator of their own copy:
# they name themselves with OPERATOR_NAME and CONTACT_EMAIL, and may close the sign-ups with SIGNUPS=closed.
module Instance
  module_function

  def official?
    ENV["INSTANCE"] == "official"
  end

  def operator_name
    ENV["OPERATOR_NAME"].to_s.strip.presence
  end

  def contact_email
    ENV["CONTACT_EMAIL"].to_s.strip.presence
  end

  # Where "Give feedback" messages go: the contact of whoever runs this copy. Only offered when the mail can leave.
  def feedback_address
    return nil unless !Rails.env.production? || ENV["SMTP_PASSWORD"].present?

    contact_email || ("contact@migraine-tracker.eu" if official?)
  end

  # Anyone may create an account unless the operator closed the sign-ups (a personal or family copy)
  def signups_open?
    ENV["SIGNUPS"].to_s.strip.downcase != "closed"
  end
end
