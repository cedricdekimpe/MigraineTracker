require "test_helper"

# The mobile app: its server description, its signed-in web screens, the account's list of devices
class NativeAppTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  APP = { "User-Agent" => "Mozilla/5.0 (Linux; Android 15) Chrome/130.0 Mobile Migraine Tracker Android; Hotwire Native Android; Turbo Native Android;" }.freeze

  test "the server describes itself for the app, without anything about the accounts" do
    get well_known_instance_path
    assert_response :success
    body = response.parsed_body
    assert_equal MyMigraineManager::VERSION, body["version"]
    assert_equal [ "v1" ], body.dig("api", "versions")
    assert_equal "http://www.example.com/api/v1", body.dig("api", "url")
    assert_includes body["privacy_url"]["fr"], "/fr/privacy-policy"
    assert_equal true, body["signups_open"]
    assert_not_includes response.body, "@example.com"
  end

  test "a one-time code from the API opens a web session, once" do
    device, = ApiToken.issue(users(:one), name: "Phone")
    code = device.issue_web_code!

    get native_session_path(code: code, to: "/fr/stats"), headers: APP
    assert_redirected_to "/fr/stats"
    get stats_path(locale: :fr), headers: APP
    assert_response :success

    sign_out users(:one)
    get native_session_path(code: code), headers: APP
    assert_redirected_to new_user_session_path
  end

  test "an expired code or an outside destination are refused" do
    device, = ApiToken.issue(users(:one), name: "Phone")
    code = device.issue_web_code!
    travel 2.minutes do
      get native_session_path(code: code)
      assert_redirected_to new_user_session_path
    end

    code = device.issue_web_code!
    get native_session_path(code: code, to: "//evil.example/steal")
    assert_redirected_to episodes_path
  end

  test "inside the app, the site leaves out its own tab bar, header, install prompt and web push" do
    sign_in users(:one)
    get account_profile_path(locale: :fr), headers: APP
    assert_response :success
    assert_select "[data-tab-bar]", count: 0
    assert_select "body > header", count: 0
    assert_select "[data-install-section]", count: 0
    assert_select "[data-controller=reminder]", count: 0
    assert_select "title", text: I18n.t("account.profile_title", locale: :fr)
  end

  test "in a browser, nothing changes" do
    sign_in users(:one)
    get account_profile_path(locale: :fr)
    assert_select "[data-tab-bar]", count: 1
    assert_select "body > header", count: 1
    assert_select "title", text: /\| Migraine Tracker/
  end

  test "the account lists its devices and signs one out" do
    device, token = ApiToken.issue(users(:one), name: "Pixel 8")
    sign_in users(:one)
    get account_profile_path(locale: :fr)
    assert_select "[data-devices]", text: /Pixel 8/

    delete account_device_path(device, locale: :fr)
    assert_redirected_to account_profile_path(anchor: "devices")
    assert_not ApiToken.authenticate(token)
  end

  test "another account's device cannot be signed out" do
    device, = ApiToken.issue(users(:two), name: "Theirs")
    sign_in users(:one)
    delete account_device_path(device, locale: :fr)
    assert_response :not_found
    assert ApiToken.exists?(device.id)
  end
end
