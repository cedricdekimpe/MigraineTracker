# "I have a headache now": start an episode in one tap, add what you take as it happens, close it
# with "it's over". Everything else (notes, exact times...) can be completed later in the normal form.
class NowController < ApplicationController
  before_action :set_ongoing_episode

  def show
    if @episode
      @medications = current_user.medications.active.where.not(kind: "preventive").most_used_first
      render :progress
    else
      @default_pain_kind = current_user.episodes.where.not(pain_kind: nil).order(:created_at).last&.pain_kind || "migraine"
      render :start
    end
  end

  def create
    return redirect_to now_path if @episode

    attributes = { occurred_on: Date.current, started_time: Time.current.strftime("%H:%M"), ongoing: true }
    attributes.merge!(
      if params[:aura_only].present?
        { aura: true }
      else
        { pain_kind: params[:pain_kind], intensity: params[:intensity], aura: params[:aura] == "1" }
      end
    )

    episode = current_user.episodes.new(attributes)
    if episode.save
      redirect_to now_path
    else
      redirect_to now_path, alert: episode.errors.full_messages.to_sentence
    end
  end

  def intensity
    return redirect_to now_path unless @episode&.pain?

    @episode.update(intensity: params[:intensity])
    redirect_to now_path
  end

  def medication
    medication = current_user.medications.active.find(params[:medication_id])
    @episode.medication_intakes.create!(medication: medication, dose: medication.default_dose, taken_time: Time.current.strftime("%H:%M"))
    redirect_to now_path
  end

  def finish
    minutes = ((Time.current - @episode.started_at) / 60).round.clamp(1, Episode::MAX_DURATION_MINUTES)
    @episode.update!(ongoing: false, duration_minutes: minutes)
    redirect_to episodes_path(month: @episode.occurred_on.strftime("%Y-%m")), notice: t("now.flash.finished", duration: helpers.duration_label(minutes))
  end

  def cancel
    @episode.destroy
    redirect_to now_path, notice: t("now.flash.cancelled")
  end

  private

  def set_ongoing_episode
    @episode = current_user.episodes.ongoing.includes(medication_intakes: :medication).order(:created_at).last
    redirect_to now_path if @episode.nil? && %w[intensity medication finish cancel].include?(action_name)
  end
end
