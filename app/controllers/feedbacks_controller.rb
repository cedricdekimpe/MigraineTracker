# frozen_string_literal: true

# "Give feedback": a short form that sends an e-mail to whoever runs this copy. Nothing is stored.
class FeedbacksController < ApplicationController
  MAX_LENGTH = 2000
  MAX_PER_DAY = 5
  RECOMMENDATIONS = %w[yes maybe no].freeze

  before_action :require_address
  before_action :limit_messages, only: :create

  def new
  end

  def create
    helps = params[:helps].to_s.strip.first(MAX_LENGTH)
    missing = params[:missing].to_s.strip.first(MAX_LENGTH)
    recommend = params[:recommend].presence_in(RECOMMENDATIONS)
    return redirect_to feedback_path, alert: t("feedback.empty") if helps.blank? && missing.blank? && recommend.nil?

    FeedbackMailer.feedback(
      address: Instance.feedback_address, helps: helps, missing: missing, recommend: recommend,
      reply_to_address: (current_user.email if params[:reply] == "1"), context: context
    ).deliver_now
    redirect_to feedback_path, notice: t("feedback.thanks")
  rescue StandardError => error
    Rails.logger.warn("Feedback not sent (#{error.class})")
    redirect_to feedback_path, alert: t("feedback.failed")
  end

  private

  # A few messages a day per account (the counter lives in the cache)
  def limit_messages
    key = "feedback/#{current_user.id}/#{Date.current}"
    count = Rails.cache.increment(key, 1, expires_in: 1.day) || (Rails.cache.write(key, 1, expires_in: 1.day) && 1)
    redirect_to feedback_path, alert: t("feedback.too_many") if count.to_i > MAX_PER_DAY
  end

  def require_address
    redirect_to account_profile_path unless Instance.feedback_address
  end

  # What helps to reproduce a problem, shown on the page too. No journal data, no address.
  def context
    {
      version: ENV["KAMAL_VERSION"].to_s.first(7).presence || "-",
      locale: I18n.locale,
      mode: (params[:mode] == "installed" ? "installed" : "browser"),
      browser: request.user_agent.to_s.first(200)
    }
  end
end
