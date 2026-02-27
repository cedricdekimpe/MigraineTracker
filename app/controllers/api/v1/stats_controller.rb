# frozen_string_literal: true

module Api
  module V1
    class StatsController < BaseController
      # GET /api/v1/stats
      def index
        migraines = current_user.migraines.includes(:medication)

        render json: {
          data: {
            type: "stats",
            id: current_user.id.to_s,
            attributes: {
              total_migraines: migraines.count,
              with_medication: migraines.where.not(medication_id: nil).count,
              without_medication: migraines.where(medication_id: nil).count,
              average_intensity: migraines.average(:intensity)&.round(1) || 0,
              on_period_count: migraines.where(on_period: true).count
            }
          },
          meta: {
            generated_at: Time.current.iso8601
          }
        }, status: :ok
      end

      # GET /api/v1/stats/monthly
      def monthly
        months_count = (params[:months] || 12).to_i.clamp(1, 24)
        start_date = months_count.months.ago.beginning_of_month

        migraines = current_user.migraines
                                .where("occurred_on >= ?", start_date)
                                .group("strftime('%Y-%m', occurred_on)")
                                .count

        # Build complete month range with zero counts for missing months
        monthly_data = (0...months_count).map do |offset|
          month = start_date + offset.months
          month_key = month.strftime("%Y-%m")
          {
            month: month_key,
            month_name: month.strftime("%B %Y"),
            count: migraines[month_key] || 0
          }
        end

        render json: {
          data: {
            type: "monthly_stats",
            id: "#{current_user.id}-monthly",
            attributes: {
              period_start: start_date.iso8601,
              period_end: Date.current.end_of_month.iso8601,
              months: monthly_data
            }
          }
        }, status: :ok
      end

      # GET /api/v1/stats/by_day_of_week
      def by_day_of_week
        migraines = current_user.migraines

        # SQLite uses 0=Sunday, 1=Monday, etc.
        day_counts = migraines.group("strftime('%w', occurred_on)").count

        days = %w[sunday monday tuesday wednesday thursday friday saturday]
        days_data = days.each_with_index.map do |day, index|
          {
            day: day,
            day_number: index,
            count: day_counts[index.to_s] || 0
          }
        end

        render json: {
          data: {
            type: "day_of_week_stats",
            id: "#{current_user.id}-dow",
            attributes: {
              days: days_data,
              total: migraines.count
            }
          }
        }, status: :ok
      end

      # GET /api/v1/stats/by_medication
      def by_medication
        migraines = current_user.migraines.includes(:medication)

        medication_counts = migraines.where.not(medication_id: nil)
                                     .joins(:medication)
                                     .group("medications.name")
                                     .count

        no_medication_count = migraines.where(medication_id: nil).count

        medications_data = medication_counts.map do |name, count|
          { name: name, count: count }
        end

        medications_data << { name: "None", count: no_medication_count } if no_medication_count > 0

        render json: {
          data: {
            type: "medication_stats",
            id: "#{current_user.id}-meds",
            attributes: {
              medications: medications_data.sort_by { |m| -m[:count] },
              total: migraines.count
            }
          }
        }, status: :ok
      end

      # GET /api/v1/stats/by_nature
      def by_nature
        migraines = current_user.migraines

        nature_counts = migraines.group(:nature).count

        natures_data = Migraine::NATURE_OPTIONS.map do |nature|
          {
            nature: nature,
            label: I18n.t("migraine_nature.#{nature}", default: nature),
            count: nature_counts[nature] || 0
          }
        end

        render json: {
          data: {
            type: "nature_stats",
            id: "#{current_user.id}-nature",
            attributes: {
              natures: natures_data,
              total: migraines.count
            }
          }
        }, status: :ok
      end

      # GET /api/v1/stats/by_intensity
      def by_intensity
        migraines = current_user.migraines

        intensity_counts = migraines.group(:intensity).count

        intensities_data = (0..10).map do |intensity|
          {
            intensity: intensity,
            count: intensity_counts[intensity] || 0
          }
        end

        render json: {
          data: {
            type: "intensity_stats",
            id: "#{current_user.id}-intensity",
            attributes: {
              intensities: intensities_data,
              total: migraines.count,
              average: migraines.average(:intensity)&.round(1) || 0
            }
          }
        }, status: :ok
      end
    end
  end
end
