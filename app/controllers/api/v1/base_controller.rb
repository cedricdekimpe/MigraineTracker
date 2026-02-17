# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      include Pagy::Backend

      before_action :authenticate_user!

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity
      rescue_from ActionController::ParameterMissing, with: :render_bad_request

      private

      def authenticate_user!
        return if current_user

        render_unauthorized
      end

      def current_user
        @current_user ||= warden.authenticate(scope: :user)
      end

      # JSON API compliant error responses
      def render_unauthorized
        render json: {
          errors: [
            {
              status: "401",
              title: "Unauthorized",
              detail: "You need to sign in or sign up before continuing."
            }
          ]
        }, status: :unauthorized
      end

      def render_not_found
        render json: {
          errors: [
            {
              status: "404",
              title: "Not Found",
              detail: "The requested resource could not be found."
            }
          ]
        }, status: :not_found
      end

      def render_unprocessable_entity(exception)
        render json: {
          errors: format_validation_errors(exception.record)
        }, status: :unprocessable_entity
      end

      def render_bad_request(exception)
        render json: {
          errors: [
            {
              status: "400",
              title: "Bad Request",
              detail: exception.message
            }
          ]
        }, status: :bad_request
      end

      def render_validation_errors(record)
        render json: {
          errors: format_validation_errors(record)
        }, status: :unprocessable_entity
      end

      def format_validation_errors(record)
        record.errors.map do |error|
          {
            status: "422",
            title: "Unprocessable Entity",
            source: { pointer: "/data/attributes/#{error.attribute}" },
            detail: error.full_message
          }
        end
      end

      # Pagination helpers for JSON API
      def pagy_metadata(pagy)
        {
          current_page: pagy.page,
          per_page: pagy.limit,
          total_pages: pagy.pages,
          total_count: pagy.count
        }
      end

      def pagy_links(pagy, url_method)
        links = {
          self: send(url_method, page: pagy.page),
          first: send(url_method, page: 1),
          last: send(url_method, page: pagy.pages)
        }
        links[:prev] = send(url_method, page: pagy.prev) if pagy.prev
        links[:next] = send(url_method, page: pagy.next) if pagy.next
        links
      end
    end
  end
end
