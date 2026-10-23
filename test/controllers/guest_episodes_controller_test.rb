require "test_helper"

class GuestEpisodesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def log_as_guest(**params)
    post guest_episode_path(locale: :fr), params: { pain_kind: "migraine", intensity: 7 }.merge(params)
  end

  test "the home page opens with the crisis form for a visitor" do
    get root_path(locale: :fr)
    assert_response :success
    assert_select "form[action=?]", guest_episode_path(locale: :fr)
    assert_select "button[name=intensity]", 10
  end

  test "a tap is kept in the session and nothing is stored" do
    assert_no_difference -> { Episode.count } do
      log_as_guest
    end
    assert_redirected_to guest_episode_path(locale: :fr)
    follow_redirect!
    assert_response :success
    assert_match "Migraine, 7/10", response.body
    assert_select "a[href=?]", new_user_registration_path(locale: :fr)
  end

  test "pain without intensity is refused" do
    log_as_guest(intensity: "")
    assert_redirected_to root_path(locale: :fr)
    get guest_episode_path(locale: :fr)
    assert_redirected_to root_path(locale: :fr)
  end

  test "aura alone is accepted" do
    post guest_episode_path(locale: :fr), params: { aura_only: "1" }
    follow_redirect!
    assert_match "Aura sans douleur", response.body
  end

  test "forgetting the entry clears it" do
    log_as_guest
    delete guest_episode_path(locale: :fr)
    get guest_episode_path(locale: :fr)
    assert_redirected_to root_path(locale: :fr)
  end

  test "signing in adds the guest crisis to the existing journal, still ongoing" do
    user = users(:one)
    user.episodes.ongoing.update_all(ongoing: false)
    log_as_guest
    assert_difference -> { user.episodes.count }, 1 do
      post user_session_path(locale: :fr), params: { user: { email: user.email, password: "password123" } }
    end
    assert_redirected_to now_path(locale: :fr)
    episode = user.episodes.order(:id).last
    assert_equal "migraine", episode.pain_kind
    assert_equal 7, episode.intensity
    assert episode.ongoing?
    assert_nil session[GuestEpisode::SESSION_KEY]
  end

  test "signing up makes it the first entry of the new journal" do
    log_as_guest
    assert_difference -> { User.count }, 1 do
      post user_registration_path(locale: :fr), params: { user: { email: "new@example.com", password: "password123", password_confirmation: "password123", health_data_consent: "1" } }
    end
    assert_equal 1, User.find_by!(email: "new@example.com").episodes.count
  end

  test "an old guest crisis is not ongoing and never replaces a running one" do
    user = users(:one)
    old = (Time.current - 20.hours).iso8601
    session_data = { "pain_kind" => "headache", "intensity" => 4, "aura" => false, "at" => old }
    episode = GuestEpisode.claim({ "guest_episode" => session_data }, user)
    assert_not episode.ongoing?

    user.episodes.create!(occurred_on: Date.current, pain_kind: "migraine", intensity: 5, ongoing: true)
    fresh = session_data.merge("at" => Time.current.iso8601)
    assert_not GuestEpisode.claim({ "guest_episode" => fresh }, user).ongoing?
  end

  test "a signed-in user is sent to the now screen" do
    sign_in users(:one)
    get guest_episode_path(locale: :fr)
    assert_redirected_to now_path(locale: :fr)
  end
end
