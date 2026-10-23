class TriggersController < ApplicationController
  def create
    trigger = current_user.triggers.new(params.require(:trigger).permit(:name))

    if trigger.save
      redirect_to account_triggers_path, notice: t("flash.trigger_created")
    else
      redirect_to account_triggers_path, alert: trigger.errors.full_messages.to_sentence
    end
  end

  def destroy
    current_user.triggers.find(params[:id]).destroy
    redirect_to account_triggers_path, notice: t("flash.trigger_deleted")
  end
end
