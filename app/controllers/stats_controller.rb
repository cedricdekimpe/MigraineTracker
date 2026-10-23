class StatsController < ApplicationController
  before_action :authenticate_user!

  def index
    @episodes = current_user.episodes

    # Total counts
    @total_episodes = @episodes.count
    @episodes_with_medication = @episodes.where(id: MedicationIntake.select(:episode_id)).count
    @episodes_without_medication = @total_episodes - @episodes_with_medication

    # Episodes over time (current month and the 11 before)
    start_date = 11.months.ago.beginning_of_month
    end_date = Date.today.end_of_month

    monthly_counts = @episodes.where(occurred_on: start_date..end_date).to_a
                              .group_by { |episode| episode.occurred_on.beginning_of_month.strftime("%b %Y") }
                              .transform_values(&:count)

    @monthly_data = (0..11).map do |i|
      month_key = (start_date + i.months).strftime("%b %Y")
      [month_key, monthly_counts[month_key] || 0]
    end

    # Distribution by day of week (Monday first, empty days included)
    day_order = %w[monday tuesday wednesday thursday friday saturday sunday]
    counts_by_day = @episodes.pluck(:occurred_on).group_by(&:cwday).transform_values(&:count)
    @day_of_week_data = day_order.each_with_index.map do |day, index|
      [I18n.t("days.#{day}"), counts_by_day.fetch(index + 1, 0)]
    end

    # Medication usage: number of intakes per medication
    @medication_data = MedicationIntake.joins(:medication, :episode)
                                       .where(episodes: { user_id: current_user.id })
                                       .group("medications.name")
                                       .order(Arel.sql("COUNT(*) DESC"))
                                       .count
                                       .to_a

    # Trigger frequency: in how many episodes each trigger was ticked
    @trigger_data = EpisodeTrigger.joins(:trigger, :episode)
                                  .where(episodes: { user_id: current_user.id })
                                  .group("triggers.name")
                                  .order(Arel.sql("COUNT(*) DESC"), Arel.sql("triggers.name"))
                                  .count
                                  .to_a
  end
end
