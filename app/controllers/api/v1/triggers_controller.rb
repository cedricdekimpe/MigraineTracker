# frozen_string_literal: true

module Api
  module V1
    class TriggersController < BaseController
      before_action :set_trigger, only: [ :update, :destroy ]

      # GET /api/v1/triggers
      def index
        render json: { data: TriggerSerializer.new(current_user.triggers.alphabetical).serializable_hash[:data] }, status: :ok
      end

      # POST /api/v1/triggers
      def create
        trigger = current_user.triggers.new(trigger_params)

        if trigger.save
          render json: { data: TriggerSerializer.new(trigger).serializable_hash[:data] }, status: :created
        else
          render_validation_errors(trigger)
        end
      end

      # PATCH/PUT /api/v1/triggers/:id
      def update
        if @trigger.update(trigger_params)
          render json: { data: TriggerSerializer.new(@trigger).serializable_hash[:data] }, status: :ok
        else
          render_validation_errors(@trigger)
        end
      end

      # DELETE /api/v1/triggers/:id
      def destroy
        @trigger.destroy
        head :no_content
      end

      private

      def set_trigger
        @trigger = current_user.triggers.find(params[:id])
      end

      def trigger_params
        params[:trigger].present? ? params.require(:trigger).permit(:name) : params.permit(:name)
      end
    end
  end
end
