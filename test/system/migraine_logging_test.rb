require "application_system_test_case"

class MigraineLoggingTest < ApplicationSystemTestCase
  setup do
    @user = User.create!({
      email: "logger@example.com",
      password: "password123",
      password_confirmation: "password123"
    }.merge(consent_attrs))
  end

  test "user records migraine entry and sees monthly calendar" do
    travel_to Date.new(2025, 12, 10) do
      visit new_user_session_path
      fill_in "Email", with: @user.email
      fill_in "Password", with: "password123"
      click_button "Sign in"

      click_link "Migraine log"
      click_link "New entry"

      fill_in "Date", with: Date.current.to_s
      select "Migraine (M)", from: "Nature"
      fill_in "Intensity (0-10)", with: 7
      check "On menstrual cycle"
      select "Ibuprofen", from: "Medication"
      click_button "Save migraine"

      assert_text "Migraine entry saved."
      within "td[data-day='10'][data-attribute='nature']" do
        assert_text "M"
      end
      within "td[data-day='10'][data-attribute='intensity']" do
        assert_text "7"
      end
      within "td[data-day='10'][data-attribute='cycle']" do
        assert_text "Yes"
      end
      within "td[data-day='10'][data-attribute='medication']" do
        assert_selector "span[title='Ibuprofen']", text: "I"
      end
    end
  end
end
