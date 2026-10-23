# frozen_string_literal: true

module Api
  module V1
    class EpisodesController < BaseController
      # The payload carries more than Episode columns (trigger_ids, nested intakes), so don't let
      # ParamsWrapper reduce it to a partial params[:episode].
      wrap_parameters false

      before_action :set_episode, only: [ :show, :update, :destroy ]

      # GET /api/v1/episodes
      def index
        episodes = scoped_episodes.order(occurred_on: :desc, started_time: :desc, id: :desc)

        # Filter by year if provided
        if params[:year].present?
          episodes = episodes.where("strftime('%Y', occurred_on) = ?", params[:year].to_s)
        end

        # Filter by month if provided
        if params[:month].present?
          episodes = episodes.where("strftime('%Y-%m', occurred_on) = ?", params[:month].to_s)
        end

        pagy, records = pagy(episodes)

        render json: {
          data: EpisodeSerializer.new(records).serializable_hash[:data],
          meta: pagy_metadata(pagy),
          links: pagy_links(pagy, :api_v1_episodes_url)
        }, status: :ok
      end

      # GET /api/v1/episodes/:id
      def show
        render json: { data: EpisodeSerializer.new(@episode).serializable_hash[:data] }, status: :ok
      end

      # POST /api/v1/episodes
      def create
        episode = current_user.episodes.new

        if save(episode)
          render json: { data: EpisodeSerializer.new(episode.reload).serializable_hash[:data] }, status: :created
        else
          render_validation_errors(episode)
        end
      end

      # PATCH/PUT /api/v1/episodes/:id
      def update
        if save(@episode)
          render json: { data: EpisodeSerializer.new(@episode.reload).serializable_hash[:data] }, status: :ok
        else
          render_validation_errors(@episode)
        end
      end

      # DELETE /api/v1/episodes/:id
      def destroy
        @episode.destroy
        head :no_content
      end

      # GET /api/v1/episodes/calendar
      def calendar
        month = params[:month].present? ? Date.strptime(params[:month], "%Y-%m") : Date.current
        month = month.beginning_of_month

        episodes = scoped_episodes.for_month(month).chronological
        episodes_by_day = episodes.group_by { |episode| episode.occurred_on.day }

        render json: {
          data: EpisodeSerializer.new(episodes).serializable_hash[:data],
          meta: {
            month: month.month,
            year: month.year,
            month_name: month.strftime("%B"),
            days_in_month: month.end_of_month.day,
            episodes_by_day: episodes_by_day.transform_values { |list| list.map(&:id) }
          }
        }, status: :ok
      rescue Date::Error
        render json: {
          errors: [ { status: "400", title: "Bad Request", detail: "Invalid month format. Use YYYY-MM." } ]
        }, status: :bad_request
      end

      # GET /api/v1/episodes/yearly
      def yearly
        year = params[:year].present? ? params[:year].to_i : Date.current.year
        start_of_year = Date.new(year, 1, 1)

        episodes = scoped_episodes.where(occurred_on: start_of_year..start_of_year.end_of_year).chronological
        grouped = episodes.group_by { |episode| episode.occurred_on.strftime("%Y-%m") }

        months_data = (1..12).map do |month_num|
          month_key = "#{year}-#{month_num.to_s.rjust(2, '0')}"
          month_episodes = grouped[month_key] || []
          {
            month: month_key,
            month_name: Date.new(year, month_num, 1).strftime("%B"),
            count: month_episodes.count,
            episode_ids: month_episodes.map(&:id)
          }
        end

        render json: {
          data: EpisodeSerializer.new(episodes).serializable_hash[:data],
          meta: { year: year, total_count: episodes.size, months: months_data }
        }, status: :ok
      end

      private

      def scoped_episodes
        current_user.episodes.includes(:triggers, medication_intakes: :medication)
      end

      def set_episode
        @episode = scoped_episodes.find(params[:id])
      end

      # Atomic: trigger links and intakes are written together with the episode or not at all.
      def save(episode)
        saved = false
        Episode.transaction do
          episode.assign_attributes(episode_params)
          saved = episode.save
          raise ActiveRecord::Rollback unless saved
        end
        saved
      end

      def episode_params
        permitted = %i[occurred_on started_time duration_minutes aura pain_kind intensity on_period notes]
        nested = { trigger_ids: [], medication_intakes_attributes: %i[id medication_id dose taken_time effect _destroy] }

        if params[:episode].present?
          params.require(:episode).permit(*permitted, **nested)
        else
          params.permit(*permitted, **nested)
        end
      end
    end
  end
end
