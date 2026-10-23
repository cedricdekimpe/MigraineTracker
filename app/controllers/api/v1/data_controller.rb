# frozen_string_literal: true

module Api
  module V1
    class DataController < BaseController
      # GET /api/v1/data/export
      def export
        payload = DataExporter.new(current_user).as_hash

        render json: {
          data: {
            type: "export",
            id: SecureRandom.uuid,
            attributes: payload
          },
          meta: {
            medications_count: payload[:medications].size,
            triggers_count: payload[:triggers].size,
            episodes_count: payload[:episodes].size
          }
        }, status: :ok
      end

      MAX_IMPORT_BYTES = 2.megabytes

      # POST /api/v1/data/import
      def import
        if request.content_length.to_i > MAX_IMPORT_BYTES
          max = ActiveSupport::NumberHelper.number_to_human_size(MAX_IMPORT_BYTES)
          return render_import_error("413", "Payload Too Large", I18n.t("import.errors.file_too_large", max: max), :content_too_large)
        end

        raw = params.require(:data)
        %i[medications triggers episodes].each do |key|
          next if raw[key].nil? || (raw[key].is_a?(Array) && raw[key].all?(ActionController::Parameters))

          return render_import_error("422", "Unprocessable Entity", I18n.t("import.errors.invalid_structure"), :unprocessable_entity)
        end

        import_data = raw.permit(
          :user_email, :format_version,
          medications: %i[name kind default_dose archived created_at],
          triggers: %i[name],
          episodes: [
            :occurred_on, :started_time, :duration_minutes, :aura, :pain_kind, :intensity, :on_period, :notes, :created_at,
            { triggers: [], medications: %i[name dose taken_time effect] }
          ]
        ).to_h

        # Validate email matches
        if import_data["user_email"].present? && import_data["user_email"] != current_user.email
          return render_import_error("422", "Unprocessable Entity", "This export file does not match your account email.", :unprocessable_entity)
        end

        result = DataImporter.new(current_user, import_data.merge("episodes" => import_data["episodes"] || [])).call

        render json: {
          data: {
            type: "import_result",
            id: SecureRandom.uuid,
            attributes: {
              imported_at: Time.current.iso8601,
              medications_imported: result.medications,
              triggers_imported: result.triggers,
              episodes_imported: result.episodes
            }
          },
          meta: {
            message: "Successfully imported #{result.medications} medications, #{result.triggers} triggers and #{result.episodes} episodes."
          }
        }, status: :ok
      rescue DataImporter::InvalidData => e
        render_import_error("422", "Unprocessable Entity", e.message, :unprocessable_entity)
      end

      private

      def render_import_error(status, title, detail, http_status)
        render json: { errors: [{ status: status, title: title, detail: detail }] }, status: http_status
      end
    end
  end
end
