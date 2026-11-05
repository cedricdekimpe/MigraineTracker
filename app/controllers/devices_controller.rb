# frozen_string_literal: true

# The account's signed-in devices of the mobile app: signing one out deletes its token.
class DevicesController < ApplicationController
  def destroy
    current_user.api_tokens.find(params[:id]).destroy!
    redirect_to account_profile_path(anchor: "devices"), notice: t("devices.signed_out")
  end
end
