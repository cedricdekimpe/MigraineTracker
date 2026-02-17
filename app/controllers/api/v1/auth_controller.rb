# frozen_string_literal: true

module Api
  module V1
    class AuthController < BaseController
      skip_before_action :authenticate_user!, only: [:login, :register]

      # POST /api/v1/auth/register
      def register
        user = User.new(register_params)

        if user.save
          token = generate_jwt_token(user)
          response.headers["Authorization"] = "Bearer #{token}"
          render json: UserSerializer.new(user).serializable_hash, status: :created
        else
          render_validation_errors(user)
        end
      end

      # POST /api/v1/auth/login
      def login
        user = User.find_by(email: login_params[:email]&.downcase)

        if user&.valid_password?(login_params[:password])
          token = generate_jwt_token(user)
          response.headers["Authorization"] = "Bearer #{token}"
          render json: UserSerializer.new(user).serializable_hash, status: :ok
        else
          render json: {
            errors: [
              {
                status: "401",
                title: "Unauthorized",
                detail: "Invalid email or password."
              }
            ]
          }, status: :unauthorized
        end
      end

      # DELETE /api/v1/auth/logout
      def logout
        # The JWT will be added to the denylist by devise-jwt
        render json: {
          meta: { message: "Successfully logged out." }
        }, status: :ok
      end

      # POST /api/v1/auth/refresh
      def refresh
        token = generate_jwt_token(current_user)
        response.headers["Authorization"] = "Bearer #{token}"
        render json: UserSerializer.new(current_user).serializable_hash, status: :ok
      end

      # GET /api/v1/auth/me
      def me
        render json: {
          data: UserSerializer.new(current_user).serializable_hash[:data]
        }, status: :ok
      end

      private

      def register_params
        if params[:user].present?
          params.require(:user).permit(:email, :password, :password_confirmation)
        else
          params.permit(:email, :password, :password_confirmation)
        end
      end

      def login_params
        if params[:user].present?
          params.require(:user).permit(:email, :password)
        else
          params.permit(:email, :password)
        end
      end

      def generate_jwt_token(user)
        Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
      end
    end
  end
end
