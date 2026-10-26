require "test_helper"

class OnboardingTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "new@example.com", password: "password123", **consent_attrs)
    sign_in @user
  end

  teardown do
    ENV.delete("VAPID_PUBLIC_KEY")
    ENV.delete("VAPID_PRIVATE_KEY")
  end

  def with_push_keys
    ENV["VAPID_PUBLIC_KEY"] = "BPublicKey"
    ENV["VAPID_PRIVATE_KEY"] = "private"
  end

  test "a new account sees the card on the journal, with the install step" do
    get episodes_path(locale: "fr")
    assert_select "[data-onboarding] h2", "Pour bien démarrer"
    assert_select "[data-onboarding] li[data-step=medications][data-done=false]"
    assert_select "[data-onboarding] li[data-step=install]"
    assert_select "[data-onboarding] li[data-step=reminder]", count: 0
  end

  test "the reminder step shows where this copy can send notifications" do
    with_push_keys
    get episodes_path(locale: "fr")
    assert_select "[data-onboarding] li[data-step=reminder][data-done=false]"
  end

  test "done steps are ticked and the card goes when everything is done" do
    with_push_keys
    @user.medications.create!(name: "Sumatriptan", kind: "triptan")
    get episodes_path(locale: "fr")
    assert_select "[data-onboarding] li[data-step=medications][data-done=true]"

    @user.update!(daily_reminder_at: "20:00")
    get episodes_path(locale: "fr")
    assert_select "[data-onboarding]", count: 0
  end

  test "without push keys the medications are the only step to do" do
    @user.medications.create!(name: "Sumatriptan", kind: "triptan")
    get episodes_path(locale: "fr")
    assert_select "[data-onboarding]", count: 0
  end

  test "Hide dismisses it for good" do
    patch account_onboarding_path(locale: "fr")
    assert_redirected_to episodes_path
    assert @user.reload.onboarding_dismissed_at

    get episodes_path(locale: "fr")
    assert_select "[data-onboarding]", count: 0
  end

  test "an account older than 30 days does not see it" do
    @user.update_column(:created_at, 31.days.ago)
    get episodes_path(locale: "fr")
    assert_select "[data-onboarding]", count: 0
  end


  test "it is not shown on the crisis screen" do
    get now_path(locale: "fr")
    assert_select "[data-onboarding]", count: 0
  end
end

class SignUpLandingTest < ActionDispatch::IntegrationTest
  def sign_up
    post user_registration_path(locale: "fr"), params: { user: { email: "fresh@example.com", password: "password123",
      password_confirmation: "password123", health_data_consent: "1" } }
  end

  test "a new account lands on the journal" do
    sign_up
    assert_redirected_to episodes_path(locale: "fr")
    follow_redirect!
    assert_select "[data-onboarding]"
  end

  test "someone who noted a crisis as a guest lands on that crisis" do
    post guest_episode_path(locale: "fr"), params: { pain_kind: "migraine", intensity: "5" }
    sign_up
    assert_redirected_to now_path(locale: "fr")
    assert User.find_by(email: "fresh@example.com").episodes.exists?
  end
end
