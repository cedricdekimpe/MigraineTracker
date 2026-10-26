class HomeController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    redirect_to now_path if user_signed_in?
    # No first screen for strangers on a copy that takes no new account
    redirect_to new_user_session_path unless user_signed_in? || Instance.signups_open?
  end
end
