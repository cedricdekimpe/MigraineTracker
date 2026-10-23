# Dated periods of a preventive medication (started, stopped, and why).
class TreatmentPeriodsController < ApplicationController
  before_action :set_medication

  def create
    period = @medication.treatment_periods.new(period_params.merge(user: current_user))
    respond_with_result(period, period.save, "created")
  end

  def update
    period = @medication.treatment_periods.find(params[:id])
    respond_with_result(period, period.update(period_params), "updated")
  end

  def destroy
    @medication.treatment_periods.find(params[:id]).destroy!
    redirect_to periods_location, notice: t("treatment_periods.flash.deleted")
  end

  private

  def set_medication
    @medication = current_user.medications.find(params[:medication_id])
  end

  def period_params
    params.require(:treatment_period).permit(:started_on, :ended_on, :dose, :stop_reason)
  end

  def respond_with_result(period, saved, key)
    if saved
      redirect_to periods_location, notice: t("treatment_periods.flash.#{key}")
    else
      redirect_to periods_location, alert: period.errors.full_messages.to_sentence
    end
  end

  def periods_location
    account_medications_path(open: @medication.id, anchor: "medication-#{@medication.id}")
  end
end
