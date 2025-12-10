require_dependency "migraines/yearly_report_pdf"

class MigrainesController < ApplicationController
  before_action :set_current_month, only: :index
  before_action :set_days, only: %i[index yearly]
  before_action :load_medications, only: %i[new create edit update]
  before_action :set_migraine, only: %i[edit update destroy]

  def index
    migraines = current_user.migraines.for_month(@current_month)
    @migraines_by_day = migraines.index_by { |migraine| migraine.occurred_on.day }
    @previous_month = @current_month.prev_month
    @next_month = @current_month.next_month
  end

  def yearly
    @current_year = extract_year
    @previous_year = @current_year - 1
    @next_year = @current_year + 1

    start_of_year = safe_date(@current_year, 1, 1)
    end_of_year = start_of_year.end_of_year

    @months = (0..11).map { |offset| start_of_year.advance(months: offset) }

    yearly_migraines = current_user.migraines.where(occurred_on: start_of_year..end_of_year)
    @grouped_migraines = yearly_migraines.group_by { |migraine| migraine.occurred_on.beginning_of_month }

    @calendars_by_month = @months.index_with do |month|
      entries = @grouped_migraines[month] || []
      entries.index_by { |migraine| migraine.occurred_on.day }
    end

    respond_to do |format|
      format.html
      format.pdf { send_yearly_pdf }
    end
  end

  def new
    @migraine = current_user.migraines.new(occurred_on: Date.current)
  end

  def create
    @migraine = current_user.migraines.new(migraine_params)

    if @migraine.save
      redirect_to migraines_path(month: @migraine.occurred_on.strftime("%Y-%m")), notice: "Migraine entry saved."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @migraine.update(migraine_params.except(:occurred_on))
      redirect_to migraines_path(month: @migraine.occurred_on.strftime("%Y-%m")), notice: "Migraine entry updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    occurred_on = @migraine.occurred_on
    @migraine.destroy
    redirect_to migraines_path(month: occurred_on.strftime("%Y-%m")), notice: "Migraine entry deleted."
  end

  private

  def set_migraine
    @migraine = current_user.migraines.find(params[:id])
  end

  def set_current_month
    @current_month = if params[:month].present?
      Date.strptime(params[:month], "%Y-%m").beginning_of_month
    else
      Date.current.beginning_of_month
    end
  rescue Date::Error
    Date.current.beginning_of_month
  end

  def set_days
    @days = (1..31).to_a
  end

  def load_medications
    @medications = current_user.medications.order(:name)
  end

  def extract_year
    return Date.current.year if params[:year].blank?

    Integer(params[:year], exception: false) || Date.current.year
  end

  def safe_date(year, month, day)
    Date.new(year, month, day)
  rescue ArgumentError
    Date.current.beginning_of_year
  end

  def migraine_params
    params.require(:migraine).permit(:occurred_on, :nature, :intensity, :on_period, :medication_id)
  end

  def send_yearly_pdf
    pdf = ::Migraines::YearlyReportPdf.new(
      user: current_user,
      year: @current_year,
      months: @months,
      grouped_migraines: @grouped_migraines,
      days: @days
    ).render

    send_data pdf,
      filename: "migraine-overview-#{@current_year}.pdf",
      type: "application/pdf",
      disposition: "attachment"
  end
end
