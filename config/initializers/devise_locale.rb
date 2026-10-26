# Devise checks "already signed in" (and similar) in callbacks it puts in front of every other one, so they
# would run before the page language is chosen: the message came out in English and led to /en. The language
# is chosen first in the Devise controllers too.
Rails.application.config.to_prepare do
  [ Devise::SessionsController, Devise::PasswordsController, Users::RegistrationsController ].each do |controller|
    controller.prepend_around_action :switch_locale
  end
end
