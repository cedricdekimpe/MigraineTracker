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
      assert_equal [ "migraine", 7, true, false ], [ episode.pain_kind, episode.intensity, episode.ongoing, episode.aura ]
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
    assert_equal [ "400 mg", "14:32" ], [ intake.dose, intake.taken_time.strftime("%H:%M") ]
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

  test "an attack running for more than 72 hours shows the doctor note" do
    @user.episodes.create!(occurred_on: Date.current - 4, started_time: "08:00", pain_kind: "migraine", intensity: 6, ongoing: true)
    get now_path
    assert_select "[data-long-attack]"
  end

  test "a fresh attack shows no note" do
    @user.episodes.create!(occurred_on: Date.current, started_time: "00:01", pain_kind: "migraine", intensity: 6, ongoing: true)
    get now_path
    assert_select "[data-long-attack]", count: 0
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

    episode = @user.episodes.order(:id).last
    assert_redirected_to now_effects_path(episode_id: episode.id) # a painful episode asks about nausea
    assert_equal "Episode saved (2 h 15).", flash[:notice]
    assert_equal [ false, 135 ], [ episode.ongoing, episode.duration_minutes ]
    assert_nil ongoing
  end

  test "a very short episode lasts at least one minute" do
    post now_path, params: { pain_kind: "headache", intensity: "2" }
    sign_in @user
    patch now_finish_path

    assert_equal 1, @user.episodes.order(:id).last.duration_minutes
  end

  test "finishing an episode with treatment asks how it worked" do
    episode = @user.episodes.create!(occurred_on: Date.current, started_time: "10:00", pain_kind: "migraine", intensity: 6, ongoing: true)
    intake = episode.medication_intakes.create!(medication: medications(:ibuprofen), dose: "400 mg", taken_time: "10:05")

    patch now_finish_path
    assert_redirected_to now_effects_path(episode_id: episode.id)
    follow_redirect!
    assert_select "li[data-intake='#{intake.id}'] button[name=effect]", 3
    assert_match(/400 mg/, response.body)
  end

  test "a painful episode without treatment still asks about nausea" do
    episode = @user.episodes.create!(occurred_on: Date.current, started_time: "10:00", pain_kind: "migraine", intensity: 6, ongoing: true)
    patch now_finish_path
    assert_redirected_to now_effects_path(episode_id: episode.id)
    follow_redirect!
    assert_select "[data-nausea] button[name=nausea]", 3
    assert_select "li[data-intake]", 0
  end

  test "an aura alone, without treatment, goes straight back to the journal" do
    episode = @user.episodes.create!(occurred_on: Date.current, started_time: "10:00", aura: true, ongoing: true)
    patch now_finish_path
    assert_redirected_to episodes_path(month: episode.occurred_on.strftime("%Y-%m"))
  end

  test "one tap records nausea, can be changed, and ignores other values" do
    episode = @user.episodes.create!(occurred_on: Date.current, pain_kind: "migraine", intensity: 6)

    patch now_nausea_path(episode_id: episode.id), params: { nausea: "vomiting" }
    assert_redirected_to now_effects_path(episode_id: episode.id)
    assert_equal "vomiting", episode.reload.nausea
    patch now_nausea_path(episode_id: episode.id), params: { nausea: "none" }
    assert_equal "none", episode.reload.nausea
    patch now_nausea_path(episode_id: episode.id), params: { nausea: "nonsense" }
    assert_nil episode.reload.nausea
  end

  test "another user's episode cannot get nausea" do
    episode = users(:two).episodes.create!(occurred_on: Date.current, pain_kind: "migraine", intensity: 5)
    patch now_nausea_path(episode_id: episode.id), params: { nausea: "nausea" }
    assert_response :not_found
    assert_nil episode.reload.nausea
  end

  test "one tap records the effect of a medication, and can be changed" do
    episode = @user.episodes.create!(occurred_on: Date.current, started_time: "10:00", pain_kind: "migraine", intensity: 6)
    intake = episode.medication_intakes.create!(medication: medications(:ibuprofen))

    patch now_intake_effect_path(id: intake.id), params: { effect: "partial" }
    assert_redirected_to now_effects_path(episode_id: episode.id)
    assert_equal "partial", intake.reload.effect

    patch now_intake_effect_path(id: intake.id), params: { effect: "good" }
    assert_equal "good", intake.reload.effect
    patch now_intake_effect_path(id: intake.id), params: { effect: "nonsense" }
    assert_nil intake.reload.effect
  end

  test "the effect of another user's intake cannot be touched" do
    other = users(:two)
    medication = other.medications.create!(name: "Mine", kind: "acute")
    intake = other.episodes.create!(occurred_on: Date.current, pain_kind: "migraine", intensity: 5).medication_intakes.create!(medication: medication)

    patch now_intake_effect_path(id: intake.id), params: { effect: "good" }
    assert_response :not_found
    assert_nil intake.reload.effect
  end

  test "the effects screen skips medications that are not treatments of the attack" do
    episode = @user.episodes.create!(occurred_on: Date.current, pain_kind: "migraine", intensity: 6)
    episode.medication_intakes.create!(medication: users(:one).medications.create!(name: "Metoclopramide", kind: "other"))
    get now_effects_path(episode_id: episode.id)
    assert_response :success
    assert_select "li[data-intake]", 0
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
    @user.episodes.create!(occurred_on: Date.current - 9, pain_kind: "migraine", intensity: 5, started_time: "10:00", ongoing: true)
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
    assert_select "a[href='#{now_path}']", text: /I have a headache/

    post now_path, params: { pain_kind: "migraine", intensity: "6" }
    sign_in @user
    get episodes_path
    assert_select "a[href='#{now_path}']", text: /Episode in progress/
  end

  # --- crises noted without network -------------------------------------------

  def send_offline(*crises)
    post now_offline_path, params: { crises: crises }, as: :json
    response.parsed_body
  end

  def offline_crisis(at, **fields)
    { id: "c#{at.to_i}", at: at.utc.iso8601, pain_kind: "migraine", intensity: "6", aura: nil, aura_only: nil }.merge(fields)
  end

  test "a crisis noted without network joins the journal at its own time, still going on when recent" do
    body = travel_to(@now + 3.hours) { send_offline(offline_crisis(@now)) }

    assert_equal [ [ "c#{@now.to_i}" ], 1 ], [ body["handled"], body["saved"] ]
    assert body["location"].end_with?("/now")
    episode = @user.episodes.order(:id).last
    assert_equal [ Date.new(2026, 10, 24), "14:32", "migraine", 6, false, true ],
                 [ episode.occurred_on, episode.started_time.strftime("%H:%M"), episode.pain_kind, episode.intensity, episode.aura, episode.ongoing ]
    assert_match(/joined the journal|rejoint le journal/, flash[:notice])
  end

  test "an older one is saved as over, an aura alone as an aura" do
    body = travel_to(@now) { send_offline(offline_crisis(@now - 2.days), offline_crisis(@now - 1.day, pain_kind: nil, intensity: nil, aura_only: "1")) }

    assert_equal 2, body["saved"]
    assert_nil body["location"]
    old, aura = @user.episodes.order(:id).last(2)
    assert_equal [ Date.new(2026, 10, 22), false ], [ old.occurred_on, old.ongoing ]
    assert_equal [ true, nil, nil ], [ aura.aura, aura.pain_kind, aura.intensity ]
  end

  test "the same crisis sent twice is saved once, and forgotten by the phone both times" do
    crisis = offline_crisis(@now - 1.day)
    travel_to(@now) do
      assert_difference -> { @user.episodes.count }, 1 do
        send_offline(crisis)
        body = send_offline(crisis)
        assert_equal [ [ crisis[:id] ], 0 ], [ body["handled"], body["saved"] ]
      end
    end
  end

  test "unusable crises are forgotten without being saved" do
    travel_to(@now) do
      assert_no_difference -> { @user.episodes.count } do
        body = send_offline(
          offline_crisis(@now - 1.day, id: "no-intensity", intensity: "0"),
          offline_crisis(@now - 1.day, id: "bad-time", at: "nonsense"),
          offline_crisis(@now + 1.day, id: "future"),
          offline_crisis(Time.zone.local(1899, 12, 31, 12), id: "too-old")
        )
        assert_equal [ %w[no-intensity bad-time future too-old], 0 ], [ body["handled"], body["saved"] ]
        assert_nil flash[:notice]
      end
    end
  end

  test "crises wait on the phone while signed out, and come by 20 at most" do
    sign_out @user
    post now_offline_path, params: { crises: [ offline_crisis(@now) ] }, as: :json
    assert_response :unauthorized

    sign_in @user
    crises = (1..25).map { |i| offline_crisis(@now - i.days, id: "c#{i}") }
    body = travel_to(@now) { send_offline(*crises) }
    assert_equal 20, body["handled"].size
  end
end
