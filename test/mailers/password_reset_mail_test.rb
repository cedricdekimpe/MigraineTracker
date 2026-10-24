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

class AuthPagesLanguageTest < ActionDispatch::IntegrationTest
  ENGLISH = /Sign in|Create account|Forgot your password|Welcome back|Need an account|Remember me|Send me password|characters minimum/

  test "the sign-in, sign-up and password pages are in French on /fr" do
    [ new_user_session_path(locale: :fr), new_user_registration_path(locale: :fr), new_user_password_path(locale: :fr) ].each do |path|
      get path
      assert_response :success
      assert_no_match(ENGLISH, response.body, path)
    end
    get new_user_password_path(locale: :fr)
    assert_select "h1", text: "Mot de passe oublié"
    assert_select "input[type=submit][value='Envoyer le lien']"
  end

  test "and in English on /en" do
    get new_user_password_path(locale: :en)
    assert_select "h1", text: "Forgot your password?"
    get new_user_registration_path(locale: :en)
    assert_select "h1", text: "Create your account"
  end

  test "the new password page takes the token from the link, in French" do
    user = users(:one)
    token = user.send_reset_password_instructions
    get edit_user_password_path(locale: :fr, reset_password_token: token)

    assert_response :success
    assert_select "h1", text: "Nouveau mot de passe"
    assert_select "input[name='user[reset_password_token]'][value=?]", token
    assert_select "input[type=submit][value='Changer mon mot de passe']"
  end

  test "a bad sign-up shows its errors in French" do
    post user_registration_path(locale: :fr), params: { user: { email: "pas-un-email", password: "court", password_confirmation: "autre", health_data_consent: "1" } }
    assert_response :unprocessable_content
    assert_no_match(/can't be blank|is invalid|is too short|doesn't match/, response.body)
    assert_select "[role=alert]", text: /Corrigez ceci/
  end
end
