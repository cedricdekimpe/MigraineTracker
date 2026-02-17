# frozen_string_literal: true

module Api
  module V1
    class MigrainesController < BaseController
      before_action :set_migraine, only: [:show, :update, :destroy]

      # GET /api/v1/migraines
      def index
        migraines = current_user.migraines.includes(:medication).order(occurred_on: :desc)

        # Filter by year if provided
        if params[:year].present?
          migraines = migraines.where("strftime('%Y', occurred_on) = ?", params[:year].to_s)
        end

        # Filter by month if provided
        if params[:month].present?
          migraines = migraines.where("strftime('%Y-%m', occurred_on) = ?", params[:month].to_s)
        end

        pagy, records = pagy(migraines)

        render json: {
          data: MigraineSerializer.new(records, include: [:medication]).serializable_hash[:data],
          meta: pagy_metadata(pagy),
          links: pagy_links(pagy, :api_v1_migraines_url)
        }, status: :ok
      end

      # GET /api/v1/migraines/:id
      def show
        render json: {
          data: MigraineSerializer.new(@migraine, include: [:medication]).serializable_hash[:data]
        }, status: :ok
      end

      # POST /api/v1/migraines
      def create
        migraine = current_user.migraines.new(migraine_params)

        if migraine.save
          render json: {
            data: MigraineSerializer.new(migraine, include: [:medication]).serializable_hash[:data]
          }, status: :created
        else
          render_validation_errors(migraine)
        end
      end

      # PATCH/PUT /api/v1/migraines/:id
      def update
        if @migraine.update(migraine_params)
          render json: {
            data: MigraineSerializer.new(@migraine, include: [:medication]).serializable_hash[:data]
          }, status: :ok
        else
          render_validation_errors(@migraine)
        end
      end

      # DELETE /api/v1/migraines/:id
      def destroy
        @migraine.destroy
        head :no_content
      end

      # GET /api/v1/migraines/calendar
      def calendar
        if params[:month].present?
          month = Date.strptime(params[:month], "%Y-%m")
        else
          month = Date.current
        end
        month = month.beginning_of_month

        migraines = current_user.migraines.includes(:medication).for_month(month)
        migraines_by_day = migraines.index_by { |m| m.occurred_on.day }

        render json: {
          data: MigraineSerializer.new(migraines, include: [:medication]).serializable_hash[:data],
          meta: {
            month: month.month,
            year: month.year,
            month_name: month.strftime("%B"),
            days_in_month: month.end_of_month.day,
            migraines_by_day: migraines_by_day.transform_values { |m| m.id }
          }
        }, status: :ok
      rescue Date::Error
        render json: {
          errors: [{ status: "400", title: "Bad Request", detail: "Invalid month format. Use YYYY-MM." }]
        }, status: :bad_request
      end

      # GET /api/v1/migraines/yearly
      def yearly
        year = params[:year].present? ? params[:year].to_i : Date.current.year
        start_of_year = Date.new(year, 1, 1)
        end_of_year = start_of_year.end_of_year

        migraines = current_user.migraines.includes(:medication)
                                .where(occurred_on: start_of_year..end_of_year)
                                .order(occurred_on: :asc)

        grouped = migraines.group_by { |m| m.occurred_on.strftime("%Y-%m") }

        months_data = (1..12).map do |month_num|
          month_key = "#{year}-#{month_num.to_s.rjust(2, '0')}"
          month_migraines = grouped[month_key] || []
          {
            month: month_key,
            month_name: Date.new(year, month_num, 1).strftime("%B"),
            count: month_migraines.count,
            migraine_ids: month_migraines.map(&:id)
          }
        end

        render json: {
          data: MigraineSerializer.new(migraines, include: [:medication]).serializable_hash[:data],
          meta: {
            year: year,
            total_count: migraines.count,
            months: months_data
          }
        }, status: :ok
      end

      private

      def set_migraine
        @migraine = current_user.migraines.find(params[:id])
      end

      def migraine_params
        if params[:migraine].present?
          params.require(:migraine).permit(:occurred_on, :nature, :intensity, :on_period, :medication_id)
        else
          params.permit(:occurred_on, :nature, :intensity, :on_period, :medication_id)
        end
      end
    end
  end
end
