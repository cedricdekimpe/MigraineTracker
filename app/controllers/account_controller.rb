# frozen_string_literal: true

class AccountController < ApplicationController
  before_action :authenticate_user!
  before_action :set_resource, only: [:profile]

  def show
    redirect_to account_profile_path
  end

  def profile
  end

  def medications
    @medications = current_user.medications.active.alphabetical
    @archived_medications = current_user.medications.archived.alphabetical
    known = current_user.medications.map { |medication| medication.name.downcase }
    @suggestions = (I18n.t("medication_suggestions.acute") + I18n.t("medication_suggestions.preventive")).reject { |name| known.include?(name.downcase) }
  end

  def triggers
    @triggers = current_user.triggers.alphabetical
  end

  def update_preferences
    current_user.update(params.require(:user).permit(:track_cycle))
    redirect_to account_profile_path, notice: t("preferences.saved")
  end

  def data
  end

  private

  # Set up resource and resource_name for Devise form compatibility
  def set_resource
    @resource = current_user
    @resource_name = :user
  end

  # Helper methods to make Devise helpers work in account views
  helper_method :resource, :resource_name, :devise_mapping

  def resource
    @resource ||= current_user
  end

  def resource_name
    :user
  end

  def devise_mapping
    @devise_mapping ||= Devise.mappings[:user]
  end
end
