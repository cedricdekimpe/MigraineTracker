class StatsController < ApplicationController
  before_action :authenticate_user!

  def index
    @overview = MonthlyOverview.new(current_user)
    @month = @overview.current
    @average = @overview.average_pain_days
    @has_data = current_user.episodes.exists?

    # Frequency of the triggers ticked on episodes. Only a list of what comes up: without the days
    # that had no episode it says nothing about cause.
    @total_episodes = current_user.episodes.count
    @trigger_data = EpisodeTrigger.joins(:trigger, :episode)
                                  .where(episodes: { user_id: current_user.id })
                                  .group("triggers.name")
                                  .order(Arel.sql("COUNT(*) DESC"), Arel.sql("triggers.name"))
                                  .count
                                  .to_a
  end
end
