require "application_system_test_case"

class EpisodeLoggingTest < ApplicationSystemTestCase
  setup do
    @user = User.create!({
      email: "logger@example.com",
      password: "password123",
      password_confirmation: "password123",
      track_cycle: true
    }.merge(consent_attrs))
    @user.medications.create!(name: "Ibuprofen", default_dose: "400 mg")

    visit new_user_session_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: "password123"
    click_button "Sign in"
  end

  test "logging an episode in a few taps shows it in the calendar" do
    travel_to Date.new(2025, 12, 10) do
      visit new_episode_path

      choose "Migraine"
      check "Aura"
      choose "7"
      check "Ibuprofen"
      check "Stress"
      click_button "Save"

      assert_text "Episode was logged."
      within "td[data-day='10'][data-attribute='type']" do
        assert_text "MA"
      end
      within "td[data-day='10'][data-attribute='intensity']" do
        assert_text "7"
      end
      within "td[data-day='10'][data-attribute='medication']" do
        assert_selector "span[title='Ibuprofen']", text: "Ibu"
      end
    end
  end

  test "a new medication and trigger can be created from the form" do
    visit new_episode_path

    choose "Headache"
    choose "3"
    fill_in "Another medication", with: "Naproxen"
    fill_in "Another trigger", with: "Chocolate"
    click_button "Save"

    assert_text "Episode was logged."
    visit history_episodes_path
    assert_text "Naproxen"
    assert_text "Chocolate"
  end

  test "submitting without aura or pain shows the reason" do
    visit new_episode_path
    click_button "Save"

    assert_text "Record an aura, a pain (migraine or headache), or both."
  end

  test "managing medications from the account page archives a used one" do
    @user.episodes.create!(occurred_on: Date.current, pain_kind: "migraine", intensity: 5).medication_intakes.create!(medication: @user.medications.first)

    visit account_medications_path
    within "li" do
      click_button "Remove"
    end

    assert_text "Medication archived"
    assert_text "Archived medications"
    visit new_episode_path
    assert_no_field "Ibuprofen"
  end

  test "headache now: start, take a medication, and close it in a few taps" do
    visit now_path

    choose "Migraine"
    click_button "7"
    assert_text "Episode in progress"
    assert_text "Migraine"

    click_button "Ibuprofen 400 mg"
    assert_text "✓ Ibuprofen 400 mg"

    click_button "It's over"
    assert_text "Episode saved"
    assert_equal 1, @user.episodes.where(ongoing: false, intensity: 7).count
    assert_equal 1, @user.episodes.last.medication_intakes.count
  end
end
