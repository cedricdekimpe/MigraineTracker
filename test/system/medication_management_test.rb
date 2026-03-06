require "application_system_test_case"

class MedicationManagementTest < ApplicationSystemTestCase
  setup do
    @user = User.create!({
      email: "meds@example.com",
      password: "password123",
      password_confirmation: "password123"
    }.merge(consent_attrs))
  end

  test "user adds and removes medication" do
    visit new_user_session_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: "password123"
    click_button "Sign in"

    click_link "Account"

    within "form[action='#{medications_path}']" do
      fill_in "Medication name", with: "Excedrin"
      click_button "Add"
    end

    assert_text "Medication added."
    assert_text "Excedrin"

    within find("li", text: "Excedrin") do
      click_button "Remove"
    end

    assert_text "Medication removed."
    assert_no_text "Excedrin"
  end
end
