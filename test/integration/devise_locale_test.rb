require "test_helper"

class DeviseLocaleTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "signed in, the sign-in page answers in the page language and stays in it" do
    sign_in users(:one)
    get new_user_session_path(locale: "fr"), headers: { "Accept-Language" => "en-US,en;q=0.9" }

    assert_redirected_to "/fr"
    assert_equal I18n.t("devise.failure.already_authenticated", locale: :fr), flash[:alert]
  end

  test "the forgotten password page too" do
    sign_in users(:one)
    get new_user_password_path(locale: "fr")

    assert_redirected_to "/fr"
  end
end
