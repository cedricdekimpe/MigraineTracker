class ApplicationController < ActionController::Base
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  around_action :switch_locale
  before_action :authenticate_user!

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # Scoped to the request: a bare `I18n.locale =` stays on the thread and leaks into the next request
  # served by it (other web pages, but also the API, which never sets a locale).
  def switch_locale(&action)
    I18n.with_locale(extract_locale || I18n.default_locale, &action)
  end

  def extract_locale
    parsed_locale = params[:locale] || session[:locale] || extract_locale_from_accept_language_header
    I18n.available_locales.map(&:to_s).include?(parsed_locale) ? parsed_locale : nil
  end

  def extract_locale_from_accept_language_header
    request.env['HTTP_ACCEPT_LANGUAGE']&.scan(/^[a-z]{2}/)&.first
  end

  def default_url_options
    { locale: I18n.locale }
  end
end
