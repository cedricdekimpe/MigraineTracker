# One tap on the cycle row: mark a day as a bleeding day, or unmark it.
class PeriodDaysController < ApplicationController
  before_action :require_cycle_tracking
  before_action :set_date

  def create
    current_user.period_days.find_or_create_by!(date: @date)
    redirect_back_or_to episodes_path(month: @date.strftime("%Y-%m"))
  end

  def destroy
    current_user.period_days.where(date: @date).destroy_all
    redirect_back_or_to episodes_path(month: @date.strftime("%Y-%m"))
  end

  private

  def require_cycle_tracking
    redirect_to episodes_path unless current_user.track_cycle?
  end

  def set_date
    @date = Date.iso8601(params[:date] || params[:id])
    head :unprocessable_entity unless JournalDates.cover?(@date)
  rescue Date::Error
    head :bad_request
  end
end
