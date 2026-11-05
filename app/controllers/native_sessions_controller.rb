# frozen_string_literal: true

# The mobile app opens its web screens signed in: it asks the API for a one-time code (valid one minute) and
# loads /app/session?code=… in its web view, which gets an ordinary web session. A wrong or used code leads to
# the sign-in page.
class NativeSessionsController < ApplicationController
  include Devise::Controllers::Rememberable

  skip_before_action :authenticate_user!

  def show
    device = ApiToken.redeem_web_code(params[:code].to_s)
    return redirect_to new_user_session_path unless device

    sign_in(device.user)
    remember_me(device.user)
    redirect_to safe_destination
  end

  private

  # A path of this site only (never "//other.site" or a full URL)
  def safe_destination
    to = params[:to].to_s
    to.match?(%r{\A/(?!/)[\w\-./?=&%]*\z}) ? to : episodes_path
  end
end
