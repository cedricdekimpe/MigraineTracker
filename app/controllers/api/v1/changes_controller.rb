# frozen_string_literal: true

module Api
  module V1
    # The journal, kept in step with the phone: GET what changed since a cursor, POST what changed on the phone.
    class ChangesController < BaseController
      def index
        since = Time.iso8601(params[:since]) if params[:since].present?
        render json: Sync::Feed.new(current_user, since: since)
      rescue ArgumentError
        render json: { error: "bad_cursor" }, status: :bad_request
      end

      def create
        render json: { results: Sync::Apply.new(current_user, body).call }
      rescue Sync::Apply::TooLarge
        render json: { error: "too_many_records", limit: Sync::Apply::LIMIT }, status: :content_too_large
      end
    end
  end
end
