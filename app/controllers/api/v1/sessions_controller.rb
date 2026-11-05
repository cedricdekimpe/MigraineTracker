# frozen_string_literal: true

module Api
  module V1
    # Signing a device in and out. The password is checked like on the web; brute force is throttled by
    # Rack::Attack (config/initializers/rack_attack.rb).
    class SessionsController < BaseController
      skip_before_action :authenticate_device!, only: :create

      def create
        email = body["email"].to_s.strip.downcase
        user = User.find_for_authentication(email: email) if email.present?
        # Same work whether the address exists or not: the answer must not tell
        valid = user ? user.valid_password?(body["password"].to_s) : User.new.valid_password?(body["password"].to_s)

        if valid && user.active_for_authentication?
          device, token = ApiToken.issue(user, name: body["device_name"])
          render json: { token: token, device_id: device.id, user: profile(user) }, status: :created
        else
          render json: { error: "invalid_credentials" }, status: :unauthorized
        end
      end

      def show
        render json: { device_id: current_device.id, user: profile(current_user) }
      end

      def destroy
        current_device.destroy!
        head :no_content
      end

      # A one-time code for the app's web view, which opens a web session with it (NativeSessionsController)
      def web_code
        render json: { code: current_device.issue_web_code!, expires_in: ApiToken::WEB_CODE_LIFETIME.to_i }
      end

      private

      def profile(user)
        { email: user.email, track_cycle: user.track_cycle }
      end
    end
  end
end
