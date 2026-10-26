class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM") { "noreply@#{ENV.fetch("APP_HOST", "localhost")}" } }
  layout "mailer"
end
