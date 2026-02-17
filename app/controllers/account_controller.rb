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
    @medications = current_user.medications.order(:name)
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
