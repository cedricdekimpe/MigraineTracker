require "test_helper"

# A copy of the code run by someone else: no author's pages, an identity of its own, optional closed sign-ups.
class SelfHostedTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def with_env(vars)
    before = vars.keys.to_h { |key| [ key, ENV[key] ] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    before.each { |key, value| ENV[key] = value }
  end

  test "the author's own pages and links exist on the official copy only" do
    get why_free_path(locale: :fr)
    assert_response :success

    with_env("INSTANCE" => nil) do
      get why_free_path(locale: :fr)
      assert_response :not_found
      get about_ai_path(locale: :fr)
      assert_response :not_found

      get faq_path(locale: :fr)
      assert_select "footer a[href='/fr/why-free']", count: 0
      assert_select "footer a[href='https://github.com/cedricdekimpe/MigraineTracker']"

      get sitemap_path(format: :xml)
      assert_not_includes response.body, "why-free"
    end
  end

  test "a copy run by someone else names its operator and does not borrow the hosted service's statements" do
    with_env("INSTANCE" => nil, "OPERATOR_NAME" => "Association Test, Belgique", "CONTACT_EMAIL" => "privacy@example.org") do
      get privacy_path(locale: :fr)
      assert_response :success
      assert_select "[data-self-hosted]"
      assert_select "#contact", text: /Association Test, Belgique/
      assert_select "#contact a[href='mailto:privacy@example.org']"
      assert_no_match(/Hetzner|BorgBase|Infomaniak|Cédric Dekimpe/, response.body)
      assert_select "[data-operator-missing]", count: 0
    end
  end

  test "an operator who did not say who they are gets a visible reminder, not the author's name" do
    with_env("INSTANCE" => nil, "OPERATOR_NAME" => nil, "CONTACT_EMAIL" => nil) do
      get privacy_path(locale: :en)
      assert_select "[data-operator-missing]"
      assert_no_match(/Cédric Dekimpe|contact@migraine-tracker.eu/, response.body)
    end
  end

  test "the FAQ gives generic answers about the server on another copy" do
    get faq_path(locale: :fr)
    assert_match(/serveur dans l'Union européenne|serveur dans l&#39;Union européenne/, response.body)

    with_env("INSTANCE" => nil) do
      get faq_path(locale: :fr)
      assert_no_match(/Union européenne|Hetzner/, response.body)
      assert_match(/exploitant de cette copie/, response.body)
    end
  end

  test "closed sign-ups: no sign-up page, no first screen, no link, but sign-in still works" do
    with_env("SIGNUPS" => "closed") do
      get new_user_registration_path(locale: :fr)
      assert_redirected_to new_user_session_path(locale: :fr)
      follow_redirect!
      assert_match(/inscriptions sont fermées/, response.body)
      assert_select "a[href*='sign_up']", count: 0

      assert_no_difference "User.count" do
        post user_registration_path(locale: :fr), params: { user: { email: "new@example.com", password: "password123", password_confirmation: "password123", health_data_consent: "1" } }
      end

      get root_path(locale: :fr)
      assert_redirected_to new_user_session_path(locale: :fr)

      post user_session_path(locale: :fr), params: { user: { email: users(:one).email, password: "password123" } }
      assert_response :redirect
    end
  end

  test "open sign-ups stay the default" do
    get new_user_registration_path(locale: :fr)
    assert_response :success
    get new_user_session_path(locale: :fr)
    assert_select "a[href*='sign_up']"
  end

  test "an existing account can still be edited when sign-ups are closed" do
    with_env("SIGNUPS" => "closed") do
      sign_in users(:one)
      get edit_user_registration_path(locale: :fr)
      assert_response :success
    end
  end
end
