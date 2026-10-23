require "test_helper"

class NowControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
    @now = Time.zone.local(2026, 10, 24, 14, 32)
  end

  def ongoing
    @user.reload.episodes.ongoing.first
  end

  # --- start ----------------------------------------------------------------

  test "requires authentication" do
    sign_out @user
    get now_path
    assert_redirected_to new_user_session_path
  end

  test "start screen offers the two pain types, aura and ten intensity buttons" do
    get now_path

    assert_response :success
    assert_select "input[name=pain_kind]", count: 2
    assert_select "input[name=aura]"
    assert_select "button[name=intensity]", count: 10
    assert_select "button[name=aura_only]"
  end

  test "the pain type defaults to the last one used" do
    @user.episodes.create!(occurred_on: Date.current - 1, pain_kind: "headache", intensity: 3)
    get now_path

    assert_select "input[name=pain_kind][value=headache][checked]"
  end

  test "one tap on an intensity starts an ongoing episode at the current local time" do
    travel_to @now do
      assert_difference "@user.episodes.count", 1 do
        post now_path, params: { pain_kind: "migraine", intensity: "7" }
      end

      assert_redirected_to now_path
      episode = ongoing
      assert_equal ["migraine", 7, true, false], [episode.pain_kind, episode.intensity, episode.ongoing, episode.aura]
      assert_equal Date.new(2026, 10, 24), episode.occurred_on
      assert_equal "14:32", episode.started_time.strftime("%H:%M")
    end
  end

  test "aura can be ticked together with the pain" do
    post now_path, params: { pain_kind: "migraine", intensity: "5", aura: "1" }
    assert ongoing.aura?
  end

  test "aura only starts an episode without pain or intensity" do
    post now_path, params: { aura_only: "1", pain_kind: "migraine" }

    episode = ongoing
    assert episode.aura?
    assert_nil episode.pain_kind
    assert_nil episode.intensity
  end

  test "starting without an intensity is refused with a reason" do
    assert_no_difference "Episode.count" do
      post now_path, params: { pain_kind: "migraine" }
    end
    assert_redirected_to now_path
    assert flash[:alert].present?
  end

  test "starting again while one is ongoing does not create a second episode" do
    post now_path, params: { pain_kind: "migraine", intensity: "4" }
    sign_in @user

    assert_no_difference "Episode.count" do
      post now_path, params: { pain_kind: "headache", intensity: "9" }
    end
    assert_equal 4, ongoing.intensity
  end

  # --- in progress ----------------------------------------------------------

  test "progress screen shows the start time, elapsed time, intensity and medication buttons" do
    travel_to @now do
      post now_path, params: { pain_kind: "migraine", intensity: "7" }
    end
    sign_in @user

    travel_to @now + 45.minutes do
      get now_path

      assert_response :success
      assert_select "h1", text: "Migraine"
      assert_match(/Since 14:32/, response.body)
      assert_match(/45 min/, response.body)
      assert_select "button[name=intensity]", count: 10
      assert_select "button[name=medication_id]", count: @user.medications.active.where.not(kind: "preventive").count
      assert_select "button[name=medication_id]", text: /Propranolol/, count: 0
      assert_select "form[action='#{now_finish_path}']"
    end
  end

  test "intensity can be corrected while it lasts" do
    post now_path, params: { pain_kind: "migraine", intensity: "4" }
    sign_in @user
    patch now_intensity_path, params: { intensity: "8" }

    assert_equal 8, ongoing.intensity
  end

  test "intensity is rejected when out of range and ignored for an aura" do
    post now_path, params: { pain_kind: "migraine", intensity: "4" }
    sign_in @user
    patch now_intensity_path, params: { intensity: "42" }
    assert_equal 4, ongoing.intensity

    ongoing.update!(ongoing: false)
    sign_in @user
    post now_path, params: { aura_only: "1" }
    sign_in @user
    patch now_intensity_path, params: { intensity: "5" }
    assert_nil ongoing.intensity
  end

  test "tapping a medication adds an intake with the default dose and the current time" do
    post now_path, params: { pain_kind: "migraine", intensity: "6" }
    sign_in @user

    travel_to @now do
      assert_difference "MedicationIntake.count", 1 do
        post now_medication_path, params: { medication_id: medications(:ibuprofen).id }
      end
    end

    intake = ongoing.medication_intakes.last
    assert_equal ["400 mg", "14:32"], [intake.dose, intake.taken_time.strftime("%H:%M")]
  end

  test "with no medication yet, the progress screen offers common ones and a name field" do
    @user.episodes.destroy_all
    @user.medications.destroy_all
    @user.episodes.create!(occurred_on: Date.current, started_time: "10:00", pain_kind: "migraine", intensity: 6, ongoing: true)
    get now_path
    assert_select "button[name=name]", text: /Ibuprof|Parac/
    assert_select "input[name=name]"
  end

  test "tapping a suggestion creates the medication with its class and logs the intake" do
    @user.episodes.destroy_all
    @user.medications.destroy_all
    @user.episodes.create!(occurred_on: Date.current, started_time: "10:00", pain_kind: "migraine", intensity: 6, ongoing: true)
    triptan = Medication.suggestions["triptan"].first
    assert_difference -> { @user.medications.count }, 1 do
      post now_medication_path, params: { name: triptan }
    end
    assert_equal "triptan", @user.medications.find_by!(name: triptan).kind
    assert_equal 1, ongoing.medication_intakes.count
  end

  test "an unknown name asks for its kind instead of guessing" do
    @user.episodes.create!(occurred_on: Date.current, started_time: "10:00", pain_kind: "migraine", intensity: 6, ongoing: true)
    assert_no_difference -> { @user.medications.count } do
      post now_medication_path, params: { name: "Mystery pill" }
    end
    assert_response :success
    assert_select "button[name=kind]", 5
    assert_select "input[name=name][value=?]", "Mystery pill"
    assert_equal 0, ongoing.medication_intakes.count
  end

  test "choosing the kind creates the medication in that class and logs the intake" do
    @user.episodes.create!(occurred_on: Date.current, started_time: "10:00", pain_kind: "migraine", intensity: 6, ongoing: true)
    post now_medication_path, params: { name: "Mystery pill", kind: "combination" }
    assert_equal "combination", @user.medications.find_by!(name: "Mystery pill").kind
    assert_equal 1, ongoing.medication_intakes.count
  end

  test "preventive is not offered as a kind for a typed name" do
    @user.episodes.create!(occurred_on: Date.current, started_time: "10:00", pain_kind: "migraine", intensity: 6, ongoing: true)
    post now_medication_path, params: { name: "Mystery pill", kind: "preventive" }
    assert_response :success
    assert_nil @user.medications.find_by(name: "Mystery pill")
  end

  test "a typed name reuses an existing medication instead of duplicating it" do
    @user.episodes.create!(occurred_on: Date.current, started_time: "10:00", pain_kind: "migraine", intensity: 6, ongoing: true)
    assert_no_difference -> { @user.medications.count } do
      post now_medication_path, params: { name: medications(:ibuprofen).name.upcase }
    end
    assert_equal medications(:ibuprofen), ongoing.medication_intakes.last.medication
  end

  test "the same medication can be taken twice" do
    post now_path, params: { pain_kind: "migraine", intensity: "6" }
    2.times do
      sign_in @user
      post now_medication_path, params: { medication_id: medications(:paracetamol).id }
    end

    assert_equal 2, ongoing.medication_intakes.count
  end

  test "another user's medication cannot be added" do
    post now_path, params: { pain_kind: "migraine", intensity: "6" }
    sign_in @user
    post now_medication_path, params: { medication_id: medications(:aspirin).id }

    assert_response :not_found
    assert_equal 0, ongoing.medication_intakes.count
  end

  # --- finish / cancel ------------------------------------------------------

  test "it's over closes the episode with its duration" do
    travel_to @now do
      post now_path, params: { pain_kind: "migraine", intensity: "6" }
    end
    sign_in @user

    travel_to @now + 135.minutes do
      patch now_finish_path
    end

    assert_redirected_to episodes_path(month: "2026-10")
    assert_equal "Episode saved (2 h 15).", flash[:notice]
    episode = @user.episodes.order(:created_at).last
    assert_equal [false, 135], [episode.ongoing, episode.duration_minutes]
    assert_nil ongoing
  end

  test "a very short episode lasts at least one minute" do
    post now_path, params: { pain_kind: "headache", intensity: "2" }
    sign_in @user
    patch now_finish_path

    assert_equal 1, @user.episodes.order(:created_at).last.duration_minutes
  end

  test "cancel deletes an episode started by mistake" do
    post now_path, params: { pain_kind: "migraine", intensity: "6" }
    sign_in @user

    assert_difference "Episode.count", -1 do
      delete now_path
    end
    assert_nil ongoing
  end

  test "actions without an ongoing episode go back to the start screen" do
    patch now_finish_path
    assert_redirected_to now_path

    sign_in @user
    delete now_path
    assert_redirected_to now_path
  end

  test "an episode forgotten for days is not shown as ongoing" do
    @user.episodes.create!(occurred_on: Date.current - 5, pain_kind: "migraine", intensity: 5, started_time: "10:00", ongoing: true)
    get now_path

    assert_select "button[name=aura_only]"
  end

  test "ongoing episodes are private to their owner" do
    sign_in users(:two)
    post now_path, params: { pain_kind: "migraine", intensity: "6" }

    sign_in @user
    get now_path
    assert_select "button[name=aura_only]"
  end

  test "the screens are translated" do
    get now_path(locale: "fr")
    assert_match(/J&#39;ai mal maintenant/, response.body)
    assert_match(/Quelle intensité/, response.body)
  end

  # --- entry points ---------------------------------------------------------

  test "the home page sends a signed-in user straight to the now screen" do
    get root_path(locale: "en")
    assert_redirected_to now_path(locale: "en")
  end

  test "the tab bar stays on the now screens so you can always get out" do
    get now_path
    assert_select "nav[aria-label='Main navigation'] a[href='#{episodes_path}']"
    assert_select "nav[aria-label='Main navigation'] a[href='#{stats_path}']"
    assert_select "nav[aria-label='Main navigation'] a[href='#{account_path}']"

    post now_path, params: { pain_kind: "migraine", intensity: "6" }
    sign_in @user
    get now_path
    assert_select "nav[aria-label='Main navigation'] a[href='#{episodes_path}']"
  end

  test "signed-in pages carry the phone shortcut and it turns into 'in progress'" do
    get episodes_path
    assert_select "a[href='#{now_path}']", text: /I have a headache now/

    post now_path, params: { pain_kind: "migraine", intensity: "6" }
    sign_in @user
    get episodes_path
    assert_select "a[href='#{now_path}']", text: /Episode in progress/
  end
end
