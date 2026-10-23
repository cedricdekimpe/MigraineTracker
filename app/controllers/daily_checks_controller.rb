# The daily check-in: a few taps about sleep, stress, meals and caffeine, for today or a day just gone.
class DailyChecksController < ApplicationController
  before_action :set_date, only: %i[show update]

  def today
    redirect_to daily_check_path(date: Date.current.iso8601)
  end

  def show
    @check = current_user.daily_checks.find_or_initialize_by(date: @date)
  end

  def update
    @check = current_user.daily_checks.find_or_initialize_by(date: @date)

    if @check.update(check_params)
      sync_period_day
      redirect_to episodes_path(month: @date.strftime("%Y-%m")), notice: t("daily_check.saved")
    else
      redirect_to daily_check_path(date: @date.iso8601), alert: @check.errors.full_messages.to_sentence
    end
  end

  private

  # The bleeding-day question (only asked with cycle tracking); left unanswered, nothing changes.
  def sync_period_day
    return unless current_user.track_cycle? && params[:period].in?(%w[yes no])

    if params[:period] == "yes"
      current_user.period_days.find_or_create_by!(date: @date)
    else
      current_user.period_days.where(date: @date).destroy_all
    end
  end

  def check_params
    params.fetch(:daily_check, {}).permit(:sleep, :stress, :skipped_meal, :caffeine)
  end

  def set_date
    @date = Date.iso8601(params[:date])
    head :unprocessable_entity if @date > Date.current || @date < 1.year.ago.to_date
  rescue Date::Error
    head :bad_request
  end
end
