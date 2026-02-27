# frozen_string_literal: true

module Api
  module V1
    class UsersController < BaseController
      # GET /api/v1/user/profile
      def show
        render json: UserSerializer.new(current_user).serializable_hash, status: :ok
      end

      # PATCH /api/v1/user/profile
      def update
        if params[:current_password].present?
          # Password change flow
          unless current_user.valid_password?(params[:current_password])
            return render json: {
              errors: [{
                status: "422",
                title: "Unprocessable Entity",
                detail: "Current password is incorrect"
              }]
            }, status: :unprocessable_entity
          end

          if current_user.update(user_params_with_password)
            render json: UserSerializer.new(current_user).serializable_hash, status: :ok
          else
            render_validation_errors(current_user)
          end
        else
          # Regular update (email only)
          if current_user.update(user_params)
            render json: UserSerializer.new(current_user).serializable_hash, status: :ok
          else
            render_validation_errors(current_user)
          end
        end
      end

      # DELETE /api/v1/user
      def destroy
        confirmation_phrase = params[:confirmation_phrase]
        password = params[:password]

        # Validate confirmation phrase
        unless confirmation_phrase == "DELETE MY ACCOUNT"
          return render json: {
            errors: [{
              status: "422",
              title: "Unprocessable Entity",
              detail: "Confirmation phrase must be 'DELETE MY ACCOUNT'"
            }]
          }, status: :unprocessable_entity
        end

        # Validate password
        unless current_user.valid_password?(password)
          return render json: {
            errors: [{
              status: "422",
              title: "Unprocessable Entity",
              detail: "Password is incorrect"
            }]
          }, status: :unprocessable_entity
        end

        # Destroy the user and all associated data
        current_user.destroy

        render json: {
          meta: {
            message: "Your account and all associated data have been permanently deleted."
          }
        }, status: :ok
      end

      private

      def user_params
        params.permit(:email)
      end

      def user_params_with_password
        params.permit(:email, :password, :password_confirmation)
      end
    end
  end
end
