# "I have a headache" for someone without an account: the tap is kept in the session until they sign in
# or sign up (see ApplicationController#after_sign_in_path_for).
class GuestEpisodesController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :redirect_signed_in_users

  def show
    @guest_episode = GuestEpisode.read(session)
    redirect_to root_path unless @guest_episode
  end

  def create
    attributes = GuestEpisode.build(params)
    return redirect_to root_path, alert: t("now.guest.invalid") unless attributes

    session[GuestEpisode::SESSION_KEY] = attributes
    redirect_to guest_episode_path
  end

  def destroy
    GuestEpisode.clear(session)
    redirect_to root_path, notice: t("now.flash.cancelled")
  end

  private

  def redirect_signed_in_users
    redirect_to now_path if user_signed_in?
  end
end
