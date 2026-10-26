# frozen_string_literal: true

# The browser of this device accepted notifications: keep where to send them. A device that changes hands
# moves to the account signed in on it.
class PushSubscriptionsController < ApplicationController
  def create
    keys = params.require(:subscription).permit(:endpoint, keys: %i[p256dh auth])
    subscription = PushSubscription.find_or_initialize_by(endpoint: keys[:endpoint])
    subscription.assign_attributes(user: current_user, p256dh: keys.dig(:keys, :p256dh), auth: keys.dig(:keys, :auth),
                                   locale: I18n.locale.to_s)

    if subscription.save
      head :created
    else
      head :unprocessable_entity
    end
  end
end
