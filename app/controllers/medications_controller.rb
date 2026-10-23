class MedicationsController < ApplicationController
  before_action :set_medication, only: %i[update destroy unarchive]

  def create
    medication = current_user.medications.new(medication_params)

    if medication.save
      redirect_to account_medications_path, notice: t("flash.medication_created")
    else
      redirect_to account_medications_path, alert: medication.errors.full_messages.to_sentence
    end
  end

  def update
    if @medication.update(medication_params)
      redirect_to account_medications_path, notice: t("flash.medication_updated")
    else
      redirect_to account_medications_path(open: @medication.id, anchor: "medication-#{@medication.id}"), alert: @medication.errors.full_messages.to_sentence
    end
  end

  # A medication that was used in past episodes is archived (history kept); an unused one is deleted.
  def destroy
    @medication.retire!
    redirect_to account_medications_path,
      notice: @medication.destroyed? ? t("flash.medication_deleted") : t("flash.medication_archived")
  end

  def unarchive
    @medication.unarchive!
    redirect_to account_medications_path, notice: t("flash.medication_restored")
  end

  private

  def set_medication
    @medication = current_user.medications.find(params[:id])
  end

  def medication_params
    params.require(:medication).permit(:name, :kind, :default_dose)
  end
end
