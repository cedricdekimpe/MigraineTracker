# "I have a headache now": start an episode in one tap, add what you take as it happens, close it
# with "it's over". Everything else (notes, exact times...) can be completed later in the normal form.
class NowController < ApplicationController
  before_action :set_ongoing_episode

  def show
    if @episode
      load_progress
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
    if params[:name].present?
      name = params[:name].to_s.strip
      kind = params[:kind].presence_in(TYPED_KINDS) || Medication.kind_for(name)
      existing = current_user.medications.find_by("lower(name) = ?", name.downcase)

      if kind.nil? && existing.nil?
        # Not a name we know: ask which kind it is rather than guess, the class decides the overuse counts.
        @unknown_name = name
        load_progress
        return render :progress
      end

      medication = existing || Medication.find_or_create_for(current_user, name, kind: kind)
      return redirect_to now_path, alert: medication.errors.full_messages.to_sentence unless medication.persisted?
    else
      medication = current_user.medications.active.find(params[:medication_id])
    end

    @episode.medication_intakes.create!(medication: medication, dose: medication.default_dose, taken_time: Time.current.strftime("%H:%M"))
    redirect_to now_path
  end

  def finish
    minutes = ((Time.current - @episode.started_at) / 60).round.clamp(1, Episode::MAX_DURATION_MINUTES)
    @episode.update!(ongoing: false, duration_minutes: minutes)
    notice = t("now.flash.finished", duration: helpers.duration_label(minutes))

    # Treatment taken: ask how it worked while it is fresh, the one figure that tells whether it suits
    if @episode.medication_intakes.any?
      redirect_to now_effects_path(episode_id: @episode.id), notice: notice
    else
      redirect_to episodes_path(month: @episode.occurred_on.strftime("%Y-%m")), notice: notice
    end
  end

  # "How did it work?": one tap per medication taken during the episode that was just closed.
  def effects
    @episode = current_user.episodes.includes(medication_intakes: :medication).find(params[:episode_id])
    @intakes = @episode.medication_intakes.reject { |intake| intake.medication.kind.in?(%w[preventive other]) }
    redirect_to episodes_path(month: @episode.occurred_on.strftime("%Y-%m")) if @intakes.empty?
  end

  def effect
    intake = MedicationIntake.joins(:episode).where(episodes: { user_id: current_user.id }).find(params[:id])
    intake.update(effect: params[:effect].presence_in(MedicationIntake::EFFECTS))
    redirect_to now_effects_path(episode_id: intake.episode_id)
  end

  def cancel
    @episode.destroy
    redirect_to now_path, notice: t("now.flash.cancelled")
  end

  private

  TYPED_KINDS = %w[acute combination triptan gepant other].freeze

  def load_progress
    @medications = current_user.medications.active.where.not(kind: "preventive").most_used_first
    known = current_user.medications.pluck(:name).map(&:downcase)
    @suggested_medications = Medication.suggestions.values_at("acute", "triptan").flatten.reject { |name| known.include?(name.downcase) }
  end

  def set_ongoing_episode
    @episode = current_user.episodes.ongoing.includes(medication_intakes: :medication).order(:created_at).last
    redirect_to now_path if @episode.nil? && %w[intensity medication finish cancel].include?(action_name)
  end
end
