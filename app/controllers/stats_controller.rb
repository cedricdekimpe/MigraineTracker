class StatsController < ApplicationController
  before_action :authenticate_user!

  def index
    @overview = MonthlyOverview.new(current_user)
    @month = @overview.current
    @average = @overview.average_pain_days
    @has_data = current_user.episodes.exists?
    @chronic_streak = @overview.chronic_streak
    @insights = TreatmentInsights.new(current_user)

    @factors = DailyFactors.new(current_user)
  end
end
