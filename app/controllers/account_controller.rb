# frozen_string_literal: true

class AccountController < ApplicationController
  before_action :authenticate_user!
  before_action :set_resource, only: [ :profile ]

  def show
    redirect_to account_profile_path
  end

  def profile
  end

  def medications
    @medications = current_user.medications.active.alphabetical
    @archived_medications = current_user.medications.archived.alphabetical
    known = current_user.medications.map { |medication| medication.name.downcase }
    @suggestions = Medication.suggestions.flat_map { |kind, names| names.map { |name| [ name, kind ] } }
                             .reject { |name, _kind| known.include?(name.downcase) }
  end

  def triggers
    @triggers = current_user.triggers.sort_by { |trigger| trigger.display_name.downcase }
    # Common examples not already in the list, in the language of the page
    owned = @triggers.map { |trigger| trigger.display_name.downcase }
    @examples = Trigger::EXAMPLE_KEYS.map { |key| I18n.t("triggers.defaults.#{key}") }.reject { |name| owned.include?(name.downcase) }
  end

  def update_preferences
    current_user.update(params.require(:user).permit(:track_cycle))
    redirect_to account_profile_path, notice: t("preferences.saved")
  end

  # The daily check-in reminder. Turned off, every device stops receiving notifications.
  def update_reminder
    if params[:enabled] == "1"
      time = params[:time].presence_in(User::DAILY_REMINDER_TIMES) || User::DEFAULT_DAILY_REMINDER_AT
      zone = params[:time_zone].presence if ActiveSupport::TimeZone[params[:time_zone].to_s]
      current_user.update!(daily_reminder_at: time, time_zone: zone || current_user.time_zone)
      redirect_to account_profile_path, notice: t("reminders.saved_on", time: time)
    else
      current_user.update!(daily_reminder_at: nil)
      current_user.push_subscriptions.destroy_all
      redirect_to account_profile_path, notice: t("reminders.saved_off")
    end
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
