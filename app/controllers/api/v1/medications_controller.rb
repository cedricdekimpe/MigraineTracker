# frozen_string_literal: true

module Api
  module V1
    class MedicationsController < BaseController
      before_action :set_medication, only: [:show, :update, :destroy]

      # GET /api/v1/medications
      def index
        medications = current_user.medications.order(:name)

        render json: {
          data: MedicationSerializer.new(medications).serializable_hash[:data]
        }, status: :ok
      end

      # GET /api/v1/medications/:id
      def show
        render json: {
          data: MedicationSerializer.new(@medication).serializable_hash[:data]
        }, status: :ok
      end

      # POST /api/v1/medications
      def create
        medication = current_user.medications.new(medication_params)

        if medication.save
          render json: {
            data: MedicationSerializer.new(medication).serializable_hash[:data]
          }, status: :created
        else
          render_validation_errors(medication)
        end
      end

      # PATCH/PUT /api/v1/medications/:id
      def update
        if @medication.update(medication_params)
          render json: {
            data: MedicationSerializer.new(@medication).serializable_hash[:data]
          }, status: :ok
        else
          render_validation_errors(@medication)
        end
      end

      # DELETE /api/v1/medications/:id
      def destroy
        @medication.destroy
        head :no_content
      end

      private

      def set_medication
        @medication = current_user.medications.find(params[:id])
      end

      def medication_params
        if params[:medication].present?
          params.require(:medication).permit(:name)
        else
          params.permit(:name)
        end
      end
    end
  end
end
