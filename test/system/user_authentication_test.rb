require "application_system_test_case"

class UserAuthenticationTest < ApplicationSystemTestCase
  test "user signs up and signs in" do
    visit root_path

    click_link "Create an account"
    fill_in "Email", with: "test@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"
    check "user_health_data_consent"
    click_button "Create account"

    assert_text "Welcome! You have signed up successfully."
    assert_text "Signed in as test@example.com"

    click_button "Sign out"
    assert_text "Signed out successfully."

    click_link "Sign in", href: new_user_session_path
    fill_in "Email", with: "test@example.com"
    fill_in "Password", with: "password123"
    click_button "Sign in"

    assert_text "Signed in successfully."
    assert_text "Signed in as test@example.com"
  end
end
