# frozen_string_literal: true

module Api
  module V1
    # The mobile app's API (docs/API.md). JSON only, no cookie: each request carries the device's token in
    # "Authorization: Bearer …". Errors are machine codes; the app writes the words.
    class BaseController < ActionController::API
      before_action :authenticate_device!

      rescue_from ActionController::ParameterMissing, JSON::ParserError do
        render json: { error: "bad_request" }, status: :bad_request
      end

      private

      attr_reader :current_device

      def current_user = current_device.user

      def authenticate_device!
        value = request.authorization.to_s[/\ABearer (.+)\z/, 1]
        @current_device = ApiToken.authenticate(value)
        render json: { error: "unauthorized" }, status: :unauthorized unless @current_device
      end

      # The request body as a Hash (the app sends JSON objects only)
      def body
        @body ||= begin
          parsed = JSON.parse(request.raw_post.presence || "{}")
          raise JSON::ParserError unless parsed.is_a?(Hash)

          parsed
        end
      end
    end
  end
end
