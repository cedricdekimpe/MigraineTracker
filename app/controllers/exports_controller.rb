class ExportsController < ApplicationController
  before_action :authenticate_user!

  def create
    # Prepare export data
    export_data = {
      exported_at: Time.current.iso8601,
      user_email: current_user.email,
      medications: current_user.medications.map do |med|
        {
          name: med.name,
          created_at: med.created_at.iso8601
        }
      end,
      migraines: current_user.migraines.includes(:medication).map do |migraine|
        {
          occurred_on: migraine.occurred_on.to_s,
          nature: migraine.nature,
          intensity: migraine.intensity,
          on_period: migraine.on_period,
          medication_name: migraine.medication&.name,
          created_at: migraine.created_at.iso8601
        }
      end
    }

    # Generate filename with timestamp
    filename = "migraine_data_#{current_user.id}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json"

    send_data export_data.to_json,
      filename: filename,
      type: 'application/json',
      disposition: 'attachment'
  end
end
