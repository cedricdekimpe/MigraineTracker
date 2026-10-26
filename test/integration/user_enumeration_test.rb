require "test_helper"

class UserEnumerationTest < ActionDispatch::IntegrationTest
  setup { ActionMailer::Base.deliveries.clear }

  def ask_reset(email)
    post user_password_path(locale: "fr"), params: { user: { email: email } }
  end

  test "the forgotten password form answers the same for a known and an unknown address" do
    ask_reset(users(:one).email)
    known = [ response.status, response.location, flash[:notice], flash[:alert] ]
    assert_equal 1, ActionMailer::Base.deliveries.size

    ask_reset("nobody@example.com")
    unknown = [ response.status, response.location, flash[:notice], flash[:alert] ]

    assert_equal known, unknown
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_match(/Si votre adresse existe/, flash[:notice])
  end

  test "sign-in says the same for an unknown address and a wrong password" do
    post user_session_path(locale: "fr"), params: { user: { email: users(:one).email, password: "wrong-password" } }
    known = response.body[/E-mail ou mot de passe incorrect/]
    post user_session_path(locale: "fr"), params: { user: { email: "nobody@example.com", password: "wrong-password" } }

    assert known
    assert_match(/E-mail ou mot de passe incorrect/, response.body)
  end
end
