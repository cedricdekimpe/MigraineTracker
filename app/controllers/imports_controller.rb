class ImportsController < ApplicationController
  MAX_FILE_SIZE = 2.megabytes

  before_action :authenticate_user!

  def new
  end

  def create
    file = params[:file]
    unless file.respond_to?(:read)
      redirect_to new_import_path, alert: t('flash.export_file_missing') and return
    end

    if file.size > MAX_FILE_SIZE
      redirect_to new_import_path,
        alert: t('flash.import_error', error: t('import.errors.file_too_large', max: helpers.number_to_human_size(MAX_FILE_SIZE))) and return
    end

    import_data = JSON.parse(file.read, max_nesting: 10)

    # Validate user email if present
    if import_data.is_a?(Hash) && import_data['user_email'].present? && import_data['user_email'] != current_user.email
      redirect_to new_import_path, alert: t('flash.import_wrong_user', email: import_data['user_email']) and return
    end

    result = DataImporter.new(current_user, import_data).call

    redirect_to edit_user_registration_path,
      notice: t('flash.import_success', medications: result.medications, migraines: result.migraines)
  rescue JSON::ParserError, JSON::NestingError
    redirect_to new_import_path, alert: t('flash.import_invalid_json')
  rescue DataImporter::InvalidData => e
    redirect_to new_import_path, alert: t('flash.import_error', error: e.message)
  end
end
