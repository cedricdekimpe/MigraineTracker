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
                      "#{resource.migraines.count} migraines, #{resource.medications.count} medications")

    super
  end

  protected

  # Override to add custom flash message key
  def set_flash_message(key, kind, options = {})
    if kind == :password_invalid
      flash[key] = I18n.t("devise.registrations.password_invalid")
    else
      super
    end
  end
end
