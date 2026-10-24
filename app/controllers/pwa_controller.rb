# frozen_string_literal: true

# What makes Migraine Tracker an installable app: the manifest (in the visitor's language), the service
# worker and the page it shows without network. None of them carries any health data, and the service
# worker never keeps a page of the journal on the device.
class PwaController < ApplicationController
  skip_before_action :authenticate_user!
  # The service worker is JavaScript the browser fetches itself, not a script requested by a page
  skip_forgery_protection only: :service_worker

  # Bump when the offline or urgent pages change while no stylesheet does, so phones fetch them again
  CACHE_REVISION = 2
  ICONS = %w[/icon.png /icon-192.png /icon.svg /apple-touch-icon.png].freeze
  # The app opens on "I have a headache now", which is always in the Night theme: no white flash
  NIGHT = "#14131a"

  def manifest
    render json: manifest_data
  end

  def service_worker
    @offline_pages = I18n.available_locales.to_h { |locale| [ locale, offline_path(locale: locale) ] }
    @cached_pages = I18n.available_locales.flat_map { |locale| [ offline_path(locale: locale), urgent_path(locale: locale) ] }
    @cached_files = [ helpers.asset_path("tailwind.css"), helpers.asset_path("application.css"), *ICONS ]
    @version = Digest::SHA256.hexdigest([ CACHE_REVISION, *@cached_files ].join("|")).first(12)
  end

  def offline
    render layout: false
  end

  private

  def manifest_data
    shortcut_icons = [ { src: "/icon-192.png", sizes: "192x192", type: "image/png" } ]
    {
      id: "/",
      name: "Migraine Tracker",
      short_name: "Migraine",
      description: t("seo.default_description"),
      lang: I18n.locale.to_s,
      dir: "ltr",
      start_url: root_path,
      scope: "/",
      display: "standalone",
      background_color: NIGHT,
      theme_color: NIGHT,
      categories: %w[health medical],
      icons: [
        { src: "/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
        { src: "/icon.png", sizes: "512x512", type: "image/png", purpose: "any" },
        # The bars sit well inside the central 80 % circle, so Android may crop it to any shape
        { src: "/icon.png", sizes: "512x512", type: "image/png", purpose: "maskable" }
      ],
      shortcuts: [
        { name: t("now.nav"), short_name: t("now.short"), url: now_path, icons: shortcut_icons },
        { name: t("daily_check.title"), url: check_path, icons: shortcut_icons }
      ]
    }
  end
end
