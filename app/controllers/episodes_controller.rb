require_dependency "reports/yearly_report_pdf"

class EpisodesController < ApplicationController
  before_action :set_current_month, only: :index
  before_action :set_days, only: %i[index yearly]
  before_action :set_episode, only: %i[edit update destroy]
  before_action :load_form_collections, only: %i[new create edit update]

  def index
    @month = @current_month
    @quarter = Sheet.quarter_of(@month)
    @sheet = Sheet.new(current_user, months: @quarter)
    @previous_month = @month.prev_month
    @next_month = @month.next_month
    @previous_quarter = @quarter.first.advance(months: -3)
    @next_quarter = @quarter.first.advance(months: 3)
  end

  def history
    @years = current_user.episodes.distinct.pluck(Arel.sql("strftime('%Y', occurred_on)")).map(&:to_i).sort.reverse
    @selected_year = params[:year].present? ? params[:year].to_i : nil
    @selected_date = parse_date(params[:date])

    episodes = current_user.episodes.includes(:medication_intakes, :medications, :triggers)
                           .order(occurred_on: :desc, started_time: :desc, id: :desc)
    episodes = episodes.where("strftime('%Y', occurred_on) = ?", @selected_year.to_s) if @selected_year
    episodes = episodes.where(occurred_on: @selected_date) if @selected_date

    @pagy, @episodes = pagy(episodes)
  end

  def yearly
    @current_year = extract_year
    @previous_year = @current_year - 1
    @next_year = @current_year + 1

    start_of_year = safe_date(@current_year, 1, 1)
    end_of_year = start_of_year.end_of_year

    @months = (0..11).map { |offset| start_of_year.advance(months: offset) }

    yearly_episodes = current_user.episodes.includes(:medications).where(occurred_on: start_of_year..end_of_year).chronological
    @grouped_episodes = yearly_episodes.group_by { |episode| episode.occurred_on.beginning_of_month }

    @sheet = Sheet.new(current_user, months: @months)

    respond_to do |format|
      format.html
      format.pdf { send_yearly_pdf }
    end
  end

  def new
    @episode = current_user.episodes.new(occurred_on: parse_date(params[:date]) || Date.current)
  end

  def create
    @episode = current_user.episodes.new

    if save_episode
      redirect_to episodes_path(month: @episode.occurred_on.strftime("%Y-%m")), notice: t("episodes.flash.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if save_episode
      redirect_to history_episodes_path(history_context), notice: t("episodes.flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    day = @episode.occurred_on
    @episode.destroy

    # Come back to the page the user was on. A day filter that just became empty falls back to the year.
    context = history_context
    context = { year: day.year } if context[:date] && !current_user.episodes.exists?(occurred_on: day)
    redirect_to history_episodes_path(context), notice: t("episodes.flash.deleted")
  end

  private

  # Filters of the history page to restore after editing or deleting an episode from it.
  def history_context
    { year: params[:year].presence, date: parse_date(params[:date])&.iso8601 }.compact
  end

  def set_current_month
    @current_month = if params[:month].present?
      Date.strptime(params[:month], "%Y-%m").beginning_of_month
    else
      Date.current.beginning_of_month
    end
  rescue Date::Error
    @current_month = Date.current.beginning_of_month
  end

  def set_days
    @days = (1..31).to_a
  end

  def load_form_collections
    # Archived medications stay selectable on episodes that already use them, so saving never drops history.
    in_use = @episode&.persisted? ? @episode.medications.archived.to_a : []
    @medications = current_user.medications.active.most_used_first.to_a + in_use
    @triggers = current_user.triggers.alphabetical
    known = (@medications + current_user.medications.archived.to_a).map { |medication| medication.name.downcase }
    suggestions = Medication.suggestions.values_at("acute", "triptan").flatten
    @suggested_medications = suggestions.reject { |name| known.include?(name.downcase) }
  end

  def set_episode
    @episode = current_user.episodes.includes(:medication_intakes, :triggers).find(params[:id])
  end

  def extract_year
    return Date.current.year if params[:year].blank?

    Integer(params[:year], exception: false) || Date.current.year
  end

  def parse_date(value)
    Date.iso8601(value.to_s) if value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
  rescue Date::Error
    nil
  end

  def safe_date(year, month, day)
    Date.new(year, month, day)
  rescue ArgumentError
    Date.current.beginning_of_year
  end

  def episode_params
    params.require(:episode).permit(
      :occurred_on, :started_time, :duration_minutes, :aura, :pain_kind, :intensity, :on_period, :notes,
      medication_intakes_attributes: %i[id dose taken_time effect _destroy]
    )
  end

  # Form fields outside the Episode columns: chips (ids), free-text additions and suggestions.
  def entry_params
    params.fetch(:episode, {}).permit(:new_medication_names, :new_trigger_names, medication_ids: [], trigger_ids: [], suggested_medications: [])
  end

  def save_episode
    entry = entry_params
    saved = false

    Episode.transaction do
      @episode.assign_attributes(episode_params)
      sync_intakes(selected_medications(entry))
      saved = @episode.save
      @episode.triggers = selected_triggers(entry) if saved
      raise ActiveRecord::Rollback unless saved
    end

    saved
  end

  def selected_medications(entry)
    chosen = current_user.medications.where(id: Array(entry[:medication_ids])).to_a
    names = split_names(entry[:new_medication_names]) + Array(entry[:suggested_medications]).map(&:to_s)
    created = names.filter_map { |name| Medication.find_or_create_for(current_user, name, kind: Medication.kind_for(name)) }.select(&:persisted?)
    (chosen + created).uniq
  end

  # Keeps one intake per ticked medication (default dose), drops the ones that were unticked.
  def sync_intakes(medications)
    wanted_ids = medications.map(&:id)

    @episode.medication_intakes.each do |intake|
      intake.mark_for_destruction unless wanted_ids.include?(intake.medication_id)
    end

    already = @episode.medication_intakes.reject(&:marked_for_destruction?).map(&:medication_id)
    medications.each do |medication|
      next if already.include?(medication.id)

      @episode.medication_intakes.build(medication: medication, dose: medication.default_dose)
    end
  end

  def selected_triggers(entry)
    chosen = current_user.triggers.where(id: Array(entry[:trigger_ids])).to_a
    created = split_names(entry[:new_trigger_names]).filter_map do |name|
      current_user.triggers.find_by("lower(name) = ?", name.downcase) || current_user.triggers.create(name: name)
    end
    (chosen + created.select(&:persisted?)).uniq
  end

  def split_names(text)
    text.to_s.split(/[,\n]/).map(&:strip).reject(&:blank?).first(10)
  end

  def send_yearly_pdf
    pdf = ::Reports::YearlyReportPdf.new(
      user: current_user,
      year: @current_year,
      months: @months,
      grouped_episodes: @grouped_episodes,
      days: @days
    ).render

    send_data pdf,
      filename: "migraine-overview-#{@current_year}.pdf",
      type: "application/pdf",
      disposition: "attachment"
  end
end
