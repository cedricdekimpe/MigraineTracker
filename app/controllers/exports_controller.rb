class ExportsController < ApplicationController
  before_action :authenticate_user!

  def create
    filename = "migraine_data_#{current_user.id}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json"

    send_data DataExporter.new(current_user).as_hash.to_json,
      filename: filename,
      type: "application/json",
      disposition: "attachment"
  end
end
