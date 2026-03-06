require "application_system_test_case"

class MigraineYearlyViewTest < ApplicationSystemTestCase
  setup do
    @user = User.create!({
      email: "overview@example.com",
      password: "password123",
      password_confirmation: "password123"
    }.merge(consent_attrs))
    ibuprofen = @user.medications.find_by(name: "Ibuprofen")
    triptan = @user.medications.find_by(name: "Triptan")

    @user.migraines.create!(occurred_on: Date.new(2025, 1, 5), nature: "M", intensity: 6, on_period: false, medication: ibuprofen)
    @user.migraines.create!(occurred_on: Date.new(2025, 6, 10), nature: "H", intensity: 4, on_period: true, medication: triptan)
  end

  test "yearly view shows entries for each month" do
    travel_to Date.new(2025, 6, 15) do
      visit new_user_session_path
      fill_in "Email", with: @user.email
      fill_in "Password", with: "password123"
      click_button "Sign in"

      click_link "Yearly overview"
      assert_text "Selected year"
      assert_link "Export yearly PDF"
      assert_selector "[data-month='2025-01'] td[data-day='5'][data-attribute='nature']", text: "M"
      assert_selector "[data-month='2025-06'] td[data-day='10'][data-attribute='medication'] span[title='Triptan']", text: "T"
    end
  end
end
