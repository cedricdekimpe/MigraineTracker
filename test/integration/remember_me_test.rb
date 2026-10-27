require "test_helper"

class RememberMeTest < ActionDispatch::IntegrationTest
  test "a new password signs in with a remember cookie, as the phone may drop the session cookie" do
    user = users(:one)
    token = user.send_reset_password_instructions
    put user_password_path(locale: "fr"), params: { user: { reset_password_token: token, password: "new-secret-123", password_confirmation: "new-secret-123" } }

    assert_response :redirect
    assert_match(/remember_user_token/, Array(response.headers["Set-Cookie"]).join("\n"))
  end

  test "unticking the box on the sign-in form is respected" do
    post user_session_path(locale: "fr"), params: { user: { email: users(:one).email, password: "password123", remember_me: "0" } }

    assert_response :redirect
    assert_no_match(/remember_user_token/, Array(response.headers["Set-Cookie"]).join("\n"))
  end
end
