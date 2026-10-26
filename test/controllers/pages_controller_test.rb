require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "the urgent-care page is public and lists both levels of urgency" do
    get urgent_path(locale: :fr)
    assert_response :success
    assert_select "[data-urgency=emergency] li", minimum: 4
    assert_select "[data-urgency=soon] li", minimum: 6
    assert_match(/112/, response.body)
    assert_match(/pas un diagnostic/, response.body)
  end

  test "it exists in English too, and is linked from the footer and the first screen" do
    get urgent_path(locale: :en)
    assert_match(/thunderclap/, response.body)
    assert_select "footer a[href=?]", urgent_path(locale: :en)

    get root_path(locale: :en)
    assert_select "a[href=?]", urgent_path(locale: :en), minimum: 1
  end

  test "'Understand my figures' needs an account and explains each statistic with its source" do
    get numbers_path(locale: :fr)
    assert_redirected_to new_user_session_path

    sign_in users(:one)
    get numbers_path(locale: :fr)
    assert_response :success
    %w[days limits nausea acute preventive chronic menstrual factors].each { |anchor| assert_select "section##{anchor} h2" }
    assert_select "section", 8
    assert_select "section#limits p.text-xs", text: /INAMI/
    assert_match(/pas un avis médical/, response.body)
  end

  test "the statistics folds its explanations behind an info button that leads to the page" do
    sign_in users(:one)
    get stats_path(locale: :en)
    assert_select "details[data-info] summary", minimum: 2
    assert_select "details[data-info] a[href=?]", numbers_path(locale: :en), minimum: 1
    assert_select "[data-info] a[href=?]", numbers_path(locale: :en, anchor: "limits")
  end

  test "the statistics carries the medical disclaimer once, at the bottom" do
    sign_in users(:one)
    get stats_path(locale: :en)
    assert_equal 1, response.body.scan("not medical advice or a diagnosis").size
    assert_no_match(/not a diagnosis/, response.body.gsub("not medical advice or a diagnosis", ""))
  end

  test "the journal legend is folded" do
    sign_in users(:one)
    get episodes_path(locale: :en)
    assert_select "details[data-legend]:not([open])"
  end

  test "the first screen is the form and a short pitch, without the long sales copy" do
    get root_path(locale: :fr)
    assert_select "ul li[itemprop=featureList]", 3
    assert_select "article p", maximum: 4
    assert_no_match(/Prêt à commencer le suivi/, response.body)
  end

  test "the privacy policy describes the data the app really keeps, in both languages" do
    get privacy_path(locale: :fr)
    assert_response :success
    %w[data technical purpose retention sharing rights contact].each { |section| assert_select "section##{section} h2" }
    %w[bilans règles périodes cookie Hetzner article].each { |word| assert_match(/#{word}/i, response.body) }
    assert_no_match(/API|Solid Queue|Remplacez/, response.body)

    get privacy_path(locale: :en)
    assert_match(/daily check-ins/, response.body)
    assert_no_match(/API|Solid Queue/, response.body)
  end

  test "the FAQ answers the current features and its structured data matches the questions" do
    get faq_path(locale: :fr)
    assert_response :success
    assert_select "[data-faq-section]", 3
    assert_select "[data-faq] details", 13
    assert_match(/J&#39;ai mal|J'ai mal/, response.body)
    assert_no_match(/Nouvelle entrée|jour de la semaine|Enregistrer la migraine/, response.body)
    assert_select "a[href=?]", privacy_path(locale: :fr, anchor: "contact")
    assert_select "a[href=?]", urgent_path(locale: :fr)

    data = JSON.parse(css_select("script[type='application/ld+json']").last.text)
    assert_equal "FAQPage", data["@type"]
    assert_equal 13, data["mainEntity"].size
    assert_equal "Comment noter une crise ?", data["mainEntity"].first["name"]
  end

  test "the FAQ tells about the reminder only where it can be turned on" do
    ENV["VAPID_PUBLIC_KEY"] = "BPublicKey"
    ENV["VAPID_PRIVATE_KEY"] = "private"
    get faq_path(locale: :fr)
    assert_select "[data-faq] details", 14
    assert_match(/Rappel du bilan du jour/, response.body)
  ensure
    ENV.delete("VAPID_PUBLIC_KEY")
    ENV.delete("VAPID_PRIVATE_KEY")
  end

  test "the consent asked at sign-up covers the whole journal" do
    get new_user_registration_path(locale: :fr)
    assert_match(/bilans du jour/, response.body)
    assert_equal "2026-10-23", User::HEALTH_DATA_CONSENT_VERSION
  end

  test "the pages on why the tool is free and on AI are public, in both languages" do
    get why_free_path(locale: :fr)
    assert_response :success
    assert_select "h1", text: "Pourquoi cet outil est gratuit"
    assert_select "[data-costs] dd", text: /4,49 € par mois, hors TVA/
    assert_select "[data-costs] dd", text: /10 € par an/
    assert_match(/Cédric Dekimpe/, response.body)
    assert_no_match(/\[Nom|\[privacy/, response.body)

    get why_free_path(locale: :en)
    assert_select "h1", text: "Why this tool is free"
    assert_select "[data-costs] dd", text: /€4.49 a month/

    get about_ai_path(locale: :fr)
    assert_response :success
    assert_select "h1", text: "Un mot sur l'IA"
    assert_select "p", text: /près de 20 ans/
    assert_select "p", text: /aucune IA dans l'outil/
    assert_select "section#source", text: /AGPL-3.0/
    assert_select "section#source a[href$='docs/SELF-HOSTING.md']", text: "Guide d'auto-hébergement (en anglais)"
    assert_select "title", text: "Un mot sur l'IA | Migraine Tracker"
    assert_no_match(/&amp;#39;|u0026#39/, response.body)

    get about_ai_path(locale: :en)
    assert_select "h1", text: "A word about AI"
  end

  test "the footer links to both pages and the sitemap lists them" do
    get root_path(locale: :fr)
    assert_select "footer a[href='/fr/why-free']"
    assert_select "footer a[href='/fr/about-ai']"
    assert_select "footer a[href='https://github.com/cedricdekimpe/MigraineTracker']", text: "Code source"

    get sitemap_path(format: :xml)
    assert_includes response.body, "/fr/why-free"
    assert_includes response.body, "/en/about-ai"
  end

  test "the privacy policy names the person responsible" do
    get privacy_path(locale: :fr)
    assert_select "#contact", text: /Cédric Dekimpe, Belgique/
    assert_select "#contact", text: /contact@migraine-tracker.eu/
  end
end
