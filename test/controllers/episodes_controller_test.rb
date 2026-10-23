require "test_helper"

class EpisodesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
  end

  test "requires authentication" do
    sign_out @user
    get episodes_path
    assert_redirected_to new_user_session_path
  end

  # --- calendar -------------------------------------------------------------

  test "calendar shows the codes of every episode of a day" do
    day = episodes(:migraine_with_aura).occurred_on
    get episodes_path(month: day.strftime("%Y-%m"))

    assert_response :success
    assert_select "td[data-day='#{day.day}'][data-attribute='type']", text: /MA · M/
    assert_select "td[data-day='#{day.day}'][data-attribute='intensity']", text: /7/
  end

  test "calendar hides the cycle row unless cycle tracking is on" do
    get episodes_path
    assert_select "td[data-attribute='cycle']", count: 0

    @user.reload.update!(track_cycle: true)
    get episodes_path
    assert_select "td[data-attribute='cycle']"
  end

  test "calendar day headers link to a new episode on that day" do
    get episodes_path
    assert_select "th a[href*='/episodes/new?date=']"
  end

  # --- new / create ---------------------------------------------------------

  test "new form defaults to today and offers chips" do
    get new_episode_path

    assert_response :success
    assert_select "input[type=date][value='#{Date.current.iso8601}']"
    assert_select "input[name='episode[pain_kind]']", count: 3
    assert_select "input[name='episode[intensity]']", count: 10
    assert_select "input[name='episode[medication_ids][]']", count: @user.medications.active.count
    assert_select "input[name='episode[trigger_ids][]']", count: @user.triggers.count
  end

  test "new form can be prefilled with a date" do
    get new_episode_path(date: "2025-03-02")
    assert_select "input[type=date][value='2025-03-02']"
  end

  test "new form hides archived medications and suggests the ones you don't have" do
    get new_episode_path

    assert_select "input[name='episode[medication_ids][]'][value='#{medications(:old_med).id}']", count: 0
    assert_select "input[name='episode[suggested_medications][]'][value='Ibuprofen']", count: 0
    assert_select "input[name='episode[suggested_medications][]'][value='Sumatriptan']"
  end

  test "cycle checkbox only appears with cycle tracking" do
    get new_episode_path
    assert_select "input[name='episode[on_period]']", count: 0

    @user.reload.update!(track_cycle: true)
    get new_episode_path
    assert_select "input[name='episode[on_period]'][type=checkbox]"
  end

  test "creates a minimal episode" do
    assert_difference "@user.episodes.count", 1 do
      post episodes_path, params: { episode: { occurred_on: "2025-02-03", pain_kind: "migraine", intensity: "6" } }
    end

    assert_redirected_to episodes_path(month: "2025-02")
    episode = @user.episodes.find_by!(occurred_on: "2025-02-03")
    assert_equal "migraine", episode.pain_kind
    assert_equal 6, episode.intensity
    assert_not episode.aura?
  end

  test "creates an aura without pain" do
    post episodes_path, params: { episode: { occurred_on: "2025-02-04", pain_kind: "", intensity: "9", aura: "1" } }

    episode = @user.episodes.find_by!(occurred_on: "2025-02-04")
    assert episode.aura?
    assert_nil episode.pain_kind
    assert_nil episode.intensity
  end

  test "rejects an episode with neither aura nor pain" do
    assert_no_difference "Episode.count" do
      post episodes_path, params: { episode: { occurred_on: "2025-02-05", pain_kind: "", aura: "0" } }
    end
    assert_response :unprocessable_entity
  end

  test "ticked medications become intakes with the default dose" do
    ibuprofen = medications(:ibuprofen)

    post episodes_path, params: { episode: { occurred_on: "2025-02-06", pain_kind: "headache", intensity: "3", medication_ids: [ibuprofen.id, medications(:paracetamol).id] } }

    episode = @user.episodes.find_by!(occurred_on: "2025-02-06")
    assert_equal 2, episode.medication_intakes.count
    assert_equal "400 mg", episode.medication_intakes.find_by!(medication: ibuprofen).dose
  end

  test "new medications can be typed or picked from suggestions without leaving the form" do
    assert_difference "@user.medications.count", 2 do
      post episodes_path, params: { episode: {
        occurred_on: "2025-02-07", pain_kind: "migraine", intensity: "8",
        new_medication_names: "Sumatriptan 50, ibuprofen",
        suggested_medications: ["Rizatriptan"]
      } }
    end

    episode = @user.episodes.find_by!(occurred_on: "2025-02-07")
    assert_equal ["Ibuprofen", "Rizatriptan", "Sumatriptan 50"], episode.medications.map(&:name).sort
  end

  test "typing the name of an archived medication brings it back" do
    post episodes_path, params: { episode: { occurred_on: "2025-02-08", pain_kind: "migraine", intensity: "4", new_medication_names: "old med" } }

    assert_not medications(:old_med).reload.archived?
    assert_includes @user.episodes.find_by!(occurred_on: "2025-02-08").medications, medications(:old_med)
  end

  test "another user's medication id is ignored" do
    post episodes_path, params: { episode: { occurred_on: "2025-02-09", pain_kind: "migraine", intensity: "4", medication_ids: [medications(:aspirin).id] } }

    assert_empty @user.episodes.find_by!(occurred_on: "2025-02-09").medications
  end

  test "ticked and typed triggers are attached" do
    assert_difference "@user.triggers.count", 1 do
      post episodes_path, params: { episode: {
        occurred_on: "2025-02-10", pain_kind: "migraine", intensity: "5",
        trigger_ids: [triggers(:stress).id], new_trigger_names: "Chocolate, stress"
      } }
    end

    names = @user.episodes.find_by!(occurred_on: "2025-02-10").triggers.map(&:name).sort
    assert_equal ["Chocolate", "Stress"], names
  end

  test "another user's trigger id is ignored" do
    post episodes_path, params: { episode: { occurred_on: "2025-02-11", pain_kind: "migraine", intensity: "5", trigger_ids: [triggers(:other_users_trigger).id] } }

    assert_empty @user.episodes.find_by!(occurred_on: "2025-02-11").triggers
  end

  test "a failed save creates no medication or trigger" do
    assert_no_difference ["Medication.count", "Trigger.count", "Episode.count"] do
      post episodes_path, params: { episode: { occurred_on: "2025-02-12", pain_kind: "", new_medication_names: "Brand New", new_trigger_names: "Brand New" } }
    end
    assert_response :unprocessable_entity
  end

  # --- edit / update --------------------------------------------------------

  test "edit shows existing choices and intake details" do
    episode = episodes(:migraine_with_aura)
    get edit_episode_path(id: episode)

    assert_response :success
    assert_select "input[name='episode[pain_kind]'][value=migraine][checked]"
    assert_select "input[name='episode[aura]'][type=checkbox][checked]"
    assert_select "input[name='episode[medication_ids][]'][value='#{medications(:ibuprofen).id}'][checked]"
    assert_select "input[name='episode[trigger_ids][]'][value='#{triggers(:stress).id}'][checked]"
    assert_select "input[value='400 mg']"
  end

  test "update adds and removes intakes but keeps the details of the ones that stay" do
    episode = episodes(:migraine_with_aura)

    patch episode_path(id: episode), params: { episode: {
      intensity: "9",
      medication_ids: [medications(:ibuprofen).id, medications(:propranolol).id]
    } }

    assert_redirected_to history_episodes_path(year: nil)
    episode.reload
    assert_equal 9, episode.intensity
    assert_equal [medications(:ibuprofen).id, medications(:propranolol).id].sort, episode.medication_intakes.map(&:medication_id).sort
    assert_equal "partial", episode.medication_intakes.find_by!(medication: medications(:ibuprofen)).effect
  end

  test "update can edit the dose, time and effect of an intake" do
    episode = episodes(:migraine_with_aura)
    intake = medication_intakes(:first_dose)

    patch episode_path(id: episode), params: { episode: {
      medication_ids: [medications(:ibuprofen).id, medications(:paracetamol).id],
      medication_intakes_attributes: { "0" => { id: intake.id, dose: "600 mg", taken_time: "09:15", effect: "good" } }
    } }

    intake.reload
    assert_equal "600 mg", intake.dose
    assert_equal "09:15", intake.taken_time.strftime("%H:%M")
    assert_equal "good", intake.effect
  end

  test "saving an episode that uses an archived medication keeps that medication" do
    episode = @user.episodes.create!(occurred_on: "2025-01-01", pain_kind: "migraine", intensity: 5)
    episode.medication_intakes.create!(medication: medications(:old_med))

    get edit_episode_path(id: episode)
    assert_select "input[name='episode[medication_ids][]'][value='#{medications(:old_med).id}'][checked]"

    patch episode_path(id: episode), params: { episode: { intensity: "6", medication_ids: [medications(:old_med).id] } }
    assert_equal [medications(:old_med)], episode.reload.medications.to_a
  end

  test "update with invalid data re-renders" do
    patch episode_path(id: episodes(:headache)), params: { episode: { pain_kind: "", aura: "0" } }
    assert_response :unprocessable_entity
    assert_equal "headache", episodes(:headache).reload.pain_kind
  end

  test "cannot edit or delete another user's episode" do
    other = episodes(:other_users)
    get edit_episode_path(id: other)
    assert_response :not_found

    assert_no_difference "Episode.count" do
      delete episode_path(id: other)
    end
  end

  test "destroy removes the episode and its links" do
    assert_difference "Episode.count", -1 do
      assert_difference "MedicationIntake.count", -2 do
        delete episode_path(id: episodes(:migraine_with_aura))
      end
    end
  end

  # --- history / yearly -----------------------------------------------------

  test "history lists episodes with medications, triggers and notes" do
    get history_episodes_path

    assert_response :success
    assert_select "li", text: /Migraine with aura/
    assert_select "li", text: /Ibuprofen 400 mg/
    assert_select "li", text: /Stress/
    assert_select "li", text: /Aura without pain/
  end

  test "history can be filtered to one day" do
    day = episodes(:migraine_with_aura).occurred_on
    get history_episodes_path(date: day.iso8601)

    assert_select "ul > li", count: 2
  end

  test "history ignores a malformed date filter" do
    get history_episodes_path(date: "nonsense")
    assert_response :success
  end

  test "yearly view renders" do
    get yearly_episodes_path(year: Date.current.year)
    assert_response :success
    assert_select "[data-month]", count: 12
  end
end
