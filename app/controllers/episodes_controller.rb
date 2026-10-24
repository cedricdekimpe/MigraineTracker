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
    # No link past the journal's limits (before 1900, after the current month)
    @previous_month = within_journal(@month.prev_month)
    @next_month = within_journal(@month.next_month)
    @previous_quarter = within_journal(@quarter.first.advance(months: -3))
    @next_quarter = within_journal(@quarter.first.advance(months: 3))
  end

  def history
    @years = current_user.episodes.distinct.pluck(Arel.sql("strftime('%Y', occurred_on)")).map(&:to_i).sort.reverse
    @selected_year = JournalDates.year(params[:year])
    @selected_date = parse_date(params[:date])

    episodes = current_user.episodes.includes(:medication_intakes, :medications, :triggers)
                           .order(occurred_on: :desc, started_time: :desc, id: :desc)
    episodes = episodes.where("strftime('%Y', occurred_on) = ?", @selected_year.to_s) if @selected_year
    episodes = episodes.where(occurred_on: @selected_date) if @selected_date

    @pagy, @episodes = pagy(episodes)
    @period_dates = current_user.period_days.where(date: @episodes.map(&:occurred_on)).pluck(:date).to_set
  end

  def yearly
    @current_year = extract_year
    @previous_year = @current_year - 1 if @current_year > JournalDates::EARLIEST.year
    @next_year = @current_year + 1 if @current_year < Date.current.year

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

  # A malformed month, or one outside the journal, shows the current one
  def set_current_month
    @current_month = JournalDates.month(params[:month]) || Date.current.beginning_of_month
  end

  def within_journal(month)
    month if month.between?(JournalDates::EARLIEST, Date.current.beginning_of_month)
  end

  def set_days
    @days = (1..31).to_a
  end

  def load_form_collections
    # Archived medications stay selectable on episodes that already use them, so saving never drops history.
    # Preventives are followed as treatment periods, not as doses of an attack: only shown on an old
    # episode that already has one.
    in_use = @episode&.persisted? ? @episode.medications.select { |medication| medication.archived? || medication.kind == "preventive" } : []
    @medications = (current_user.medications.active.where.not(kind: "preventive").most_used_first.to_a + in_use).uniq
    @triggers = current_user.triggers.sort_by { |trigger| trigger.display_name.downcase }
    known = (@medications + current_user.medications.archived.to_a).map { |medication| medication.name.downcase }
    # The few most common ones only (three painkillers, three triptans); the rest is typed
    suggestions = Medication.suggestions["acute"].first(3) + Medication.suggestions["triptan"].first(3)
    @suggested_medications = suggestions.reject { |name| known.include?(name.downcase) }
  end

  def set_episode
    @episode = current_user.episodes.includes(:medication_intakes, :triggers).find(params[:id])
  end

  def extract_year
    JournalDates.year(params[:year]) || Date.current.year
  end

  # A date of the journal (ISO 8601), or nil
  def parse_date(value)
    date = Date.iso8601(value.to_s) if value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
    date if date && JournalDates.cover?(date)
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
      :occurred_on, :started_time, :duration_minutes, :aura, :pain_kind, :intensity, :nausea, :notes,
      medication_intakes_attributes: %i[id dose taken_time effect _destroy]
    )
  end

  # Form fields outside the Episode columns: chips (ids), free-text additions and suggestions.
  def entry_params
    params.fetch(:episode, {}).permit(:new_medication_names, :new_trigger_names, :new_medication_kind, :period_day, medication_ids: [], trigger_ids: [], suggested_medications: [])
  end

  def save_episode
    entry = entry_params
    saved = false

    Episode.transaction do
      @episode.assign_attributes(episode_params)
      sync_intakes(selected_medications(entry))
      saved = @episode.save
      @episode.triggers = selected_triggers(entry) if saved
      sync_period_day(entry) if saved
      raise ActiveRecord::Rollback unless saved
    end

    saved
  end

  # The "period" box of the form edits the bleeding day of the episode's date (only when the form had it).
  def sync_period_day(entry)
    return unless current_user.track_cycle? && entry.key?(:period_day)

    days = current_user.period_days
    if ActiveModel::Type::Boolean.new.cast(entry[:period_day])
      days.find_or_create_by!(date: @episode.occurred_on)
    else
      days.where(date: @episode.occurred_on).destroy_all
    end
  end

  def selected_medications(entry)
    chosen = current_user.medications.where(id: Array(entry[:medication_ids])).to_a
    names = split_names(entry[:new_medication_names]) + Array(entry[:suggested_medications]).map(&:to_s)
    typed_kind = entry[:new_medication_kind].presence_in(Medication::KINDS) || "acute"
    created = names.filter_map { |name| Medication.find_or_create_for(current_user, name, kind: Medication.kind_for(name) || typed_kind) }.select(&:persisted?)
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
      default_key = Trigger.default_key_for(name)
      current_user.triggers.find_by("lower(name) = ?", name.downcase) ||
        (default_key && current_user.triggers.find_by(key: default_key)) ||
        current_user.triggers.create(name: name, key: default_key)
    end
    (chosen + created.select(&:persisted?)).uniq
  end

  def split_names(text)
    text.to_s.split(/[,\n]/).map(&:strip).reject(&:blank?).first(10)
  end

  def send_yearly_pdf
    pdf = ::Reports::YearlyReportPdf.new(user: current_user, year: @current_year).render

    send_data pdf,
      filename: "migraine-calendar-#{@current_year}.pdf",
      type: "application/pdf",
      disposition: "attachment"
  end
end
