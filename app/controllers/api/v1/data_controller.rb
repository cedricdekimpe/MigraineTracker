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

      # POST /api/v1/data/import
      def import
        import_data = params.require(:data).permit!

        # Validate email matches
        if import_data[:user_email].present? && import_data[:user_email] != current_user.email
          return render json: {
            errors: [{
              status: "422",
              title: "Unprocessable Entity",
              detail: "This export file does not match your account email (#{import_data[:user_email]})."
            }]
          }, status: :unprocessable_entity
        end

        imported_medications = 0
        imported_migraines = 0

        ActiveRecord::Base.transaction do
          # Import medications
          if import_data[:medications].present?
            import_data[:medications].each do |med_data|
              med = current_user.medications.find_or_initialize_by(name: med_data[:name])
              if med.new_record? && med.save
                imported_medications += 1
              end
            end
          end

          # Import migraines
          if import_data[:migraines].present?
            import_data[:migraines].each do |migraine_data|
              occurred_on = Date.parse(migraine_data[:occurred_on])

              # Skip if migraine already exists for this date
              next if current_user.migraines.exists?(occurred_on: occurred_on)

              medication = nil
              if migraine_data[:medication_name].present?
                medication = current_user.medications.find_or_create_by(name: migraine_data[:medication_name])
              end

              migraine = current_user.migraines.new(
                occurred_on: occurred_on,
                nature: migraine_data[:nature],
                intensity: migraine_data[:intensity],
                on_period: migraine_data[:on_period] || false,
                medication: medication
              )

              if migraine.save
                imported_migraines += 1
              end
            end
          end
        end

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
      rescue JSON::ParserError, ArgumentError => e
        render json: {
          errors: [{
            status: "400",
            title: "Bad Request",
            detail: "Invalid import data format: #{e.message}"
          }]
        }, status: :bad_request
      end
    end
  end
end
