# frozen_string_literal: true

module Api
  module V1
    class StatsController < BaseController
      # GET /api/v1/stats
      def index
        episodes = current_user.episodes
        with_medication = episodes.where(id: MedicationIntake.select(:episode_id)).count

        render json: {
          data: {
            type: "stats",
            id: current_user.id.to_s,
            attributes: {
              total_episodes: episodes.count,
              with_medication: with_medication,
              without_medication: episodes.count - with_medication,
              average_intensity: episodes.average(:intensity)&.to_f&.round(1) || 0,
              aura_count: episodes.where(aura: true).count,
              on_period_count: episodes.where(on_period: true).count
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
        # The current month plus the previous (months_count - 1)
        start_date = (months_count - 1).months.ago.beginning_of_month

        counts = current_user.episodes
                             .where("occurred_on >= ?", start_date)
                             .group("strftime('%Y-%m', occurred_on)")
                             .count

        monthly_data = (0...months_count).map do |offset|
          month = start_date + offset.months
          month_key = month.strftime("%Y-%m")
          {
            month: month_key,
            month_name: month.strftime("%B %Y"),
            count: counts[month_key] || 0
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
        episodes = current_user.episodes

        # SQLite: 0 = Sunday, 1 = Monday, ...
        day_counts = episodes.group("strftime('%w', occurred_on)").count

        days = %w[sunday monday tuesday wednesday thursday friday saturday]
        days_data = days.each_with_index.map do |day, index|
          { day: day, day_number: index, count: day_counts[index.to_s] || 0 }
        end

        render json: {
          data: {
            type: "day_of_week_stats",
            id: "#{current_user.id}-dow",
            attributes: { days: days_data, total: episodes.count }
          }
        }, status: :ok
      end

      # GET /api/v1/stats/by_medication
      def by_medication
        intakes = MedicationIntake.joins(:medication, :episode).where(episodes: { user_id: current_user.id })
        counts = intakes.group("medications.name").count
        episodes = current_user.episodes
        without_medication = episodes.count - episodes.where(id: MedicationIntake.select(:episode_id)).count

        medications_data = counts.map { |name, count| { name: name, count: count } }
        medications_data << { name: "None", count: without_medication } if without_medication.positive?

        render json: {
          data: {
            type: "medication_stats",
            id: "#{current_user.id}-meds",
            attributes: {
              medications: medications_data.sort_by { |medication| -medication[:count] },
              total: episodes.count
            }
          }
        }, status: :ok
      end

      # GET /api/v1/stats/by_pain_kind
      def by_pain_kind
        episodes = current_user.episodes
        counts = episodes.group(:pain_kind).count

        kinds = Episode::PAIN_KINDS.map { |kind| { kind: kind, count: counts[kind] || 0 } }
        kinds << { kind: "aura_only", count: counts[nil] || 0 }

        render json: {
          data: {
            type: "pain_kind_stats",
            id: "#{current_user.id}-pain-kind",
            attributes: {
              kinds: kinds,
              with_aura: episodes.where(aura: true).count,
              total: episodes.count
            }
          }
        }, status: :ok
      end

      # GET /api/v1/stats/by_intensity
      def by_intensity
        episodes = current_user.episodes.where.not(intensity: nil)
        counts = episodes.group(:intensity).count

        intensities_data = (1..10).map { |intensity| { intensity: intensity, count: counts[intensity] || 0 } }

        render json: {
          data: {
            type: "intensity_stats",
            id: "#{current_user.id}-intensity",
            attributes: {
              intensities: intensities_data,
              total: episodes.count,
              average: episodes.average(:intensity)&.to_f&.round(1) || 0
            }
          }
        }, status: :ok
      end

      # GET /api/v1/stats/by_trigger
      def by_trigger
        counts = EpisodeTrigger.joins(:trigger, :episode)
                               .where(episodes: { user_id: current_user.id })
                               .group("triggers.name")
                               .count

        render json: {
          data: {
            type: "trigger_stats",
            id: "#{current_user.id}-triggers",
            attributes: {
              triggers: counts.map { |name, count| { name: name, count: count } }.sort_by { |trigger| [ -trigger[:count], trigger[:name] ] },
              total_episodes: current_user.episodes.count
            }
          }
        }, status: :ok
      end
    end
  end
end
