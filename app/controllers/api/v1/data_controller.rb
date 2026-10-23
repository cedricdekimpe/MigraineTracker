# frozen_string_literal: true

module Api
  module V1
    class DataController < BaseController
      # GET /api/v1/data/export
      def export
        medications = current_user.medications.order(:name)
        migraines = current_user.migraines.includes(:medication).order(occurred_on: :desc)

        export_data = {
          data: {
            type: "export",
            id: SecureRandom.uuid,
            attributes: {
              exported_at: Time.current.iso8601,
              user_email: current_user.email,
              medications: medications.map do |med|
                {
                  name: med.name,
                  created_at: med.created_at.iso8601
                }
              end,
              migraines: migraines.map do |migraine|
                {
                  occurred_on: migraine.occurred_on.iso8601,
                  nature: migraine.nature,
                  intensity: migraine.intensity,
                  on_period: migraine.on_period,
                  medication_name: migraine.medication&.name,
                  created_at: migraine.created_at.iso8601
                }
              end
            }
          },
          meta: {
            medications_count: medications.count,
            migraines_count: migraines.count
          }
        }

        render json: export_data, status: :ok
      end

      MAX_IMPORT_BYTES = 2.megabytes

      # POST /api/v1/data/import
      def import
        if request.content_length.to_i > MAX_IMPORT_BYTES
          max = ActiveSupport::NumberHelper.number_to_human_size(MAX_IMPORT_BYTES)
          return render_import_error("413", "Payload Too Large", I18n.t("import.errors.file_too_large", max: max), :payload_too_large)
        end

        raw = params.require(:data)
        %i[medications migraines].each do |key|
          next if raw[key].nil? || (raw[key].is_a?(Array) && raw[key].all?(ActionController::Parameters))

          return render_import_error("422", "Unprocessable Entity", I18n.t("import.errors.invalid_structure"), :unprocessable_entity)
        end

        import_data = raw.permit(
          :user_email,
          medications: %i[name created_at],
          migraines: %i[occurred_on nature intensity on_period medication_name created_at]
        ).to_h

        # Validate email matches
        if import_data["user_email"].present? && import_data["user_email"] != current_user.email
          return render_import_error("422", "Unprocessable Entity", "This export file does not match your account email.", :unprocessable_entity)
        end

        result = DataImporter.new(current_user, import_data.merge("migraines" => import_data["migraines"] || [])).call
        imported_medications = result.medications
        imported_migraines = result.migraines

        render json: {
          data: {
            type: "import_result",
            id: SecureRandom.uuid,
            attributes: {
              imported_at: Time.current.iso8601,
              medications_imported: imported_medications,
              migraines_imported: imported_migraines
            }
          },
          meta: {
            message: "Successfully imported #{imported_medications} medications and #{imported_migraines} migraines."
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
