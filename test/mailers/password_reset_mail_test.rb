require "test_helper"

class PasswordResetMailTest < ActionDispatch::IntegrationTest
  setup { ActionMailer::Base.deliveries.clear }

  test "the reset mail comes from the contact address, in the page's language, plain text first" do
    post user_password_path(locale: :fr), params: { user: { email: users(:one).email } }

    assert_equal 1, ActionMailer::Base.deliveries.size
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "contact@migraine-tracker.eu" ], mail.from
    assert_equal [ users(:one).email ], mail.to
    assert_equal "Réinitialisez votre mot de passe Migraine Tracker", mail.subject
    assert_match(%r{/fr/users/password/edit\?reset_password_token=}, mail.text_part.body.to_s)
    assert_includes mail.text_part.body.to_s, "Si ce n'était pas vous"
  end

  test "the English page gets the English mail" do
    post user_password_path(locale: :en), params: { user: { email: users(:one).email } }
    assert_equal "Reset your Migraine Tracker password", ActionMailer::Base.deliveries.last.subject
  end

  test "an unknown address reveals nothing and sends nothing" do
    post user_password_path(locale: :fr), params: { user: { email: "nobody@example.com" } }
    assert_empty ActionMailer::Base.deliveries
  end

  test "sign-in errors speak French on the French page" do
    post user_session_path(locale: :fr), params: { user: { email: users(:one).email, password: "wrong" } }
    assert_match(/E-mail ou mot de passe incorrect/, response.body)
  end
end
