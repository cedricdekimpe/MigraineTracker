require "test_helper"

class FeedbacksControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
    ENV["CONTACT_EMAIL"] = "me@example.org"
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    ENV.delete("CONTACT_EMAIL")
    Rails.cache = @cache
  end

  def with_env(vars)
    before = vars.keys.to_h { |key| [ key, ENV[key] ] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    before.each { |key, value| ENV[key] = value }
  end

  def send_feedback(**params)
    post feedback_path(locale: "fr"), params: { mode: "installed", **params }
  end

  test "the form is in the account and the footer, with the three questions" do
    get feedback_path(locale: "fr")
    assert_response :success
    assert_select "textarea[name=helps]"
    assert_select "textarea[name=missing]"
    assert_select "fieldset[data-question=recommend] input[type=radio]", 3
    assert_select "input[type=checkbox][name=reply]:not([checked])"
    assert_select "footer a[href=?]", feedback_path(locale: "fr"), text: "Donner mon avis"
  end

  test "the message goes by e-mail to whoever runs this copy, without the sender's address" do
    send_feedback(helps: "Le calendrier", missing: "Un export CSV", recommend: "yes")

    assert_redirected_to feedback_path
    assert_equal "Merci, c'est bien reçu.", flash[:notice]
    mail = ActionMailer::Base.deliveries.sole
    assert_equal [ "me@example.org" ], mail.to
    assert_empty Array(mail.reply_to)
    assert_includes mail.body.to_s, "Le calendrier"
    assert_includes mail.body.to_s, "Un export CSV"
    assert_includes mail.body.to_s, "yes"
    assert_includes mail.body.to_s, "mode: installed"
    assert_not_includes mail.body.to_s, @user.email
  end

  test "the address of the account is the reply address only when the box is ticked" do
    send_feedback(helps: "Bien", reply: "1")
    assert_equal [ @user.email ], ActionMailer::Base.deliveries.sole.reply_to
  end

  test "an empty message is refused, and so is a very long one cut" do
    send_feedback(helps: "  ", missing: "")
    assert_equal "Écrivez au moins un mot, ou choisissez une réponse.", flash[:alert]
    assert_empty ActionMailer::Base.deliveries

    send_feedback(helps: "a" * 5000)
    assert_equal 2000, ActionMailer::Base.deliveries.sole.body.to_s[/a{100,}/].size
  end

  test "an answer alone is enough, an unknown answer is not" do
    send_feedback(recommend: "maybe")
    assert_equal 1, ActionMailer::Base.deliveries.size

    send_feedback(recommend: "whatever")
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "five messages a day per account" do
    5.times { send_feedback(helps: "Encore") }
    assert_equal 5, ActionMailer::Base.deliveries.size

    send_feedback(helps: "Trop")
    assert_equal 5, ActionMailer::Base.deliveries.size
    assert_equal "Vous avez déjà envoyé plusieurs messages aujourd'hui. Réessayez demain.", flash[:alert]
  end

  test "needs an account" do
    sign_out @user
    get feedback_path(locale: "fr")
    assert_redirected_to new_user_session_path
  end

  test "a copy that names no contact does not offer it" do
    with_env("INSTANCE" => nil, "CONTACT_EMAIL" => nil) do
      get feedback_path(locale: "fr")
      assert_redirected_to account_profile_path

      get account_profile_path(locale: "fr")
      assert_select "a[href=?]", feedback_path(locale: "fr"), count: 0
    end
  end

  test "the official copy sends to the contact address" do
    with_env("CONTACT_EMAIL" => nil) do
      send_feedback(helps: "Bien")
      assert_equal [ "contact@migraine-tracker.eu" ], ActionMailer::Base.deliveries.sole.to
    end
  end
end
