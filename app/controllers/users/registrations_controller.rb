# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  # DELETE /resource
  def destroy
    # Verify password before deletion for extra security
    unless resource.valid_password?(params[:password])
      set_flash_message(:alert, :password_invalid)
      redirect_to edit_user_registration_path and return
    end

    # Log deletion stats before destroying (for audit purposes if needed)
    Rails.logger.info("Account deletion: User #{resource.id} (#{resource.email}) - " \
                      "#{resource.episodes.count} episodes, #{resource.medications.count} medications")

    super
  end

  before_action :configure_sign_up_params, only: [ :create ]
  before_action :require_open_signups, only: [ :new, :create ]

  protected

  # A new account starts on the journal, where the get-started card is. Whoever noted a crisis as a guest
  # still lands on that crisis, as before.
  def after_sign_up_path_for(resource)
    guest = GuestEpisode.read(session).present?
    path = after_sign_in_path_for(resource)
    guest ? path : episodes_path
  end

  # A closed copy (SIGNUPS=closed) takes no new account; existing accounts are untouched
  def require_open_signups
    redirect_to new_user_session_path, alert: t("auth.signups_closed") unless Instance.signups_open?
  end

  # Override to add custom flash message key
  def set_flash_message(key, kind, options = {})
    if kind == :password_invalid
      flash[key] = I18n.t("devise.registrations.password_invalid")
    else
      super
    end
  end

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :health_data_consent ])
  end
end
