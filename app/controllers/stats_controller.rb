class StatsController < ApplicationController
  before_action :authenticate_user!

  def index
    @migraines = current_user.migraines.includes(:medication)
    
    # Total counts
    @total_migraines = @migraines.count
    @migraines_with_medication = @migraines.where.not(medication_id: nil).count
    @migraines_without_medication = @total_migraines - @migraines_with_medication
    
    # Migraines over time (last 12 months)
    start_date = 11.months.ago.beginning_of_month
    end_date = Date.today.end_of_month
    
    # Group migraines by month
    migraines_in_range = @migraines.where("occurred_on >= ? AND occurred_on <= ?", start_date, end_date).to_a
    monthly_counts = migraines_in_range.group_by { |m| m.occurred_on.beginning_of_month.strftime("%b %Y") }
                                       .transform_values(&:count)
    
    # Fill in all months with counts
    @monthly_data = (0..11).map do |i|
      month = start_date + i.months
      month_key = month.strftime("%b %Y")
      count = monthly_counts[month_key] || 0
      [month_key, count]
    end
    
    # Distribution by day of week
    day_order = %w[monday tuesday wednesday thursday friday saturday sunday]
    counts_by_day = @migraines.group_by { |m| m.occurred_on.cwday }.transform_values(&:count)
    @day_of_week_data = day_order.each_with_index.map do |day, index|
      [I18n.t("days.#{day}"), counts_by_day.fetch(index + 1, 0)]
    end
    
    # Medication usage
    @medication_data = @migraines
      .joins(:medication)
      .group("medications.name")
      .count
      .to_a
  end
end
