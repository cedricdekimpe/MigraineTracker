require "test_helper"

class TriggersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
  end

  test "account page lists triggers" do
    get account_triggers_path
    assert_response :success
    assert_select "li", text: /Lack of sleep/
    assert_select "li", text: /Stress/
  end

  test "create adds a trigger and rejects duplicates" do
    assert_difference "@user.triggers.count", 1 do
      post triggers_path, params: { trigger: { name: "Chocolate" } }
    end
    assert_no_difference "Trigger.count" do
      post triggers_path, params: { trigger: { name: "chocolate" } }
    end
    assert flash[:alert].present?
  end

  test "destroy removes the trigger from episodes but keeps them" do
    assert_no_difference "Episode.count" do
      assert_difference "EpisodeTrigger.count", -1 do
        delete trigger_path(id: triggers(:stress))
      end
    end
  end

  test "cannot delete another user's trigger" do
    delete trigger_path(id: triggers(:other_users_trigger))
    assert_response :not_found
  end

  test "preferences toggle cycle tracking" do
    assert_not @user.track_cycle?
    patch account_preferences_path, params: { user: { track_cycle: "1" } }
    assert_redirected_to account_profile_path
    assert @user.reload.track_cycle?

    get account_profile_path
    assert_select "input[name='user[track_cycle]'][type=checkbox][checked]"
  end

  test "preferences cannot change other attributes" do
    patch account_preferences_path, params: { user: { track_cycle: "1", email: "x@example.com", health_data_consent_version: "hacked" } }
    @user.reload
    assert_equal "user@example.com", @user.email
    assert_not_equal "hacked", @user.health_data_consent_version
  end

  test "the account pages offer a way to sign out, and it works" do
    get account_profile_path
    assert_select "form[action*='/users/sign_out'] button", text: /Sign out/

    sign_in @user
    delete destroy_user_session_path
    follow_redirect!
    get account_profile_path
    assert_redirected_to new_user_session_path
  end
end
