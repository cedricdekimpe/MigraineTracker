require "test_helper"

class PwaControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def manifest(locale)
    get pwa_manifest_path(locale: locale, format: :json)
    assert_response :success
    JSON.parse(response.body)
  end

  test "the manifest speaks the visitor's language and keeps one identity" do
    fr = manifest(:fr)
    en = manifest(:en)

    assert_equal [ "/", "/" ], [ fr["id"], en["id"] ]
    assert_equal [ "/fr", "/en" ], [ fr["start_url"], en["start_url"] ]
    assert_equal [ "fr", "en" ], [ fr["lang"], en["lang"] ]
    assert_equal [ "/fr/now", "/fr/check" ], fr["shortcuts"].map { |shortcut| shortcut["url"] }
    assert_equal "J'ai mal", fr["shortcuts"].first["name"]
    assert_equal "I have a headache", en["shortcuts"].first["name"]
  end

  test "the manifest opens dark, does not lock the orientation and has a maskable icon" do
    data = manifest(:fr)

    assert_equal "standalone", data["display"]
    assert_equal [ "#14131a", "#14131a" ], [ data["background_color"], data["theme_color"] ]
    assert_not data.key?("orientation")
    assert data["icons"].any? { |icon| icon["purpose"] == "maskable" && icon["sizes"] == "512x512" }
    data["icons"].each { |icon| assert File.exist?(Rails.root.join("public", icon["src"].delete_prefix("/"))), icon["src"] }
  end

  test "the service worker is served at the root, without sign-in, for both languages" do
    get "/service-worker.js"

    assert_response :success
    assert_equal "text/javascript", response.media_type
    assert_not_includes response.headers["Cache-Control"].to_s, "max-age=3"
    assert_includes response.body, "/fr/offline"
    assert_includes response.body, "/en/urgent"
    assert_includes response.body, ActionController::Base.helpers.asset_path("tailwind.css")
    assert_match(/const VERSION = "\h{12}"/, response.body)
  end

  test "the offline page shows nothing personal, even to someone signed in" do
    user = users(:one)
    sign_in user
    get offline_path(locale: :fr)

    assert_response :success
    assert_select "[data-offline] h1", text: "Pas de connexion"
    assert_select "meta[name=robots][content=noindex]"
    assert_select "a[href='/fr/urgent']"
    assert_not_includes response.body, user.email
  end

  test "the layout links the manifest of the page's language and names the app for iOS" do
    sign_in users(:one)
    get episodes_path(locale: :en)

    assert_select "link[rel=manifest][href^='/en/manifest']"
    assert_select "meta[name=apple-mobile-web-app-title][content=Migraine]"
    assert_select "meta[name=viewport][content*='viewport-fit=cover']"
    assert_select "meta[name=theme-color][data-theme-color]", count: 2
  end

  test "the crisis screen colours the phone's bar in Night only" do
    sign_in users(:one)
    get now_path

    assert_select "meta[name=theme-color]", count: 1
    assert_select "meta[name=theme-color][content='#14131a']:not([media])"
  end

  test "the account offers to install, hidden until the browser allows it" do
    sign_in users(:one)
    get account_profile_path

    assert_select "section[data-controller=install][hidden]"
  end

  test "sign-in remembers by default, for three months renewed at each return" do
    get new_user_session_path(locale: :fr)

    assert_select "input[type=checkbox][name='user[remember_me]'][checked]"
    assert_select "label", text: /Se souvenir de moi/
    assert_equal 3.months, Devise.remember_for
    assert Devise.extend_remember_period
  end

  test "without network the offline page still takes a crisis, in Night, with the same form" do
    get offline_path(locale: :fr)

    assert_select "body[data-theme=night][data-offline]"
    assert_select "[data-offline-form] form input[name=pain_kind]", count: 2
    assert_select "[data-offline-form] form button[name=intensity]", count: 10
    assert_select "[data-offline-form] form button[name=aura_only]"
    assert_select "[data-offline-noted][hidden][data-template*='__TIME__']"
  end

  test "signed-in pages send the crises noted offline; visitors' pages do not" do
    get root_path(locale: :fr)
    assert_select "body[data-controller~=offline-queue]", count: 0

    sign_in users(:one)
    get episodes_path(locale: :fr)
    assert_select "body[data-controller~=offline-queue]"
  end
end
