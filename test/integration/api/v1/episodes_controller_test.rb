# frozen_string_literal: true

require "test_helper"

class Api::V1::EpisodesControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @user = users(:one)
    @token = nil
    @episode = episodes(:migraine_with_aura)
  end

  def authenticated_token
    @token ||= login_user(@user.email, "password123")
  end

  def post_episode(token: authenticated_token, **attributes)
    post "/api/v1/episodes", params: attributes.to_json, headers: api_headers(token)
  end

  # --- index / show ---------------------------------------------------------

  test "index returns the user's episodes, newest first, with details" do
    get "/api/v1/episodes", headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_collection("episode")
    assert_equal 4, json_response[:data].length
    assert_equal episodes(:second_same_day).id.to_s, json_response[:data].first[:id]

    attrs = json_response[:data].find { |e| e[:id] == @episode.id.to_s }[:attributes]
    assert_equal "MA", attrs[:code]
    assert_equal "08:30", attrs[:started_time]
    assert_equal ["Lack of sleep", "Stress"], attrs[:triggers].map { |t| t[:name] }.sort
    assert_equal ["Ibuprofen", "Paracetamol"], attrs[:medications].map { |m| m[:name] }.sort
  end

  test "index filters by year and month" do
    get "/api/v1/episodes", params: { month: @episode.occurred_on.strftime("%Y-%m") }, headers: api_headers(authenticated_token)
    assert_response :success
    assert json_response[:data].all? { |e| e[:attributes][:occurred_on].start_with?(@episode.occurred_on.strftime("%Y-%m")) }

    get "/api/v1/episodes", params: { year: "1999" }, headers: api_headers(authenticated_token)
    assert_empty json_response[:data]
  end

  test "index fails without authentication" do
    get "/api/v1/episodes", headers: api_headers
    assert_response :unauthorized
  end

  test "show returns an episode" do
    get "/api/v1/episodes/#{@episode.id}", headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_resource("episode", @episode.id)
  end

  test "show hides another user's episode and unknown ids" do
    get "/api/v1/episodes/#{episodes(:other_users).id}", headers: api_headers(authenticated_token)
    assert_response :not_found

    get "/api/v1/episodes/999999", headers: api_headers(authenticated_token)
    assert_response :not_found
  end

  # --- create ---------------------------------------------------------------

  test "create a migraine with aura, intakes and triggers" do
    assert_difference ["@user.episodes.count", "MedicationIntake.count"], 1 do
      post_episode(
        occurred_on: "2025-04-01", started_time: "07:15", duration_minutes: 120, aura: true, pain_kind: "migraine", intensity: 8,
        trigger_ids: [triggers(:stress).id],
        medication_intakes_attributes: [{ medication_id: medications(:ibuprofen).id, dose: "400 mg", effect: "partial" }]
      )
    end

    assert_response :created
    attrs = json_response[:data][:attributes]
    assert_equal "MA", attrs[:code]
    assert_equal "07:15", attrs[:started_time]
    assert_equal ["Stress"], attrs[:triggers].map { |t| t[:name] }
    assert_equal "partial", attrs[:medications].first[:effect]
  end

  test "create also accepts attributes wrapped in an episode key" do
    post_episode(episode: { occurred_on: "2025-04-02", pain_kind: "headache", intensity: 3 })
    assert_response :created
  end

  test "create an isolated aura" do
    post_episode(occurred_on: "2025-04-03", aura: true)

    assert_response :created
    attrs = json_response[:data][:attributes]
    assert_equal "A", attrs[:code]
    assert_nil attrs[:intensity]
  end

  test "create several episodes on the same day" do
    2.times { post_episode(occurred_on: "2025-04-04", pain_kind: "migraine", intensity: 5) }
    assert_equal 2, @user.episodes.where(occurred_on: "2025-04-04").count
  end

  test "create fails without aura or pain" do
    assert_no_difference "Episode.count" do
      post_episode(occurred_on: "2025-04-05")
    end
    assert_response :unprocessable_entity
    assert json_response[:errors].present?
  end

  test "create fails for pain without intensity or with an invalid one" do
    post_episode(occurred_on: "2025-04-06", pain_kind: "migraine")
    assert_response :unprocessable_entity

    post_episode(occurred_on: "2025-04-06", pain_kind: "migraine", intensity: 11)
    assert_response :unprocessable_entity

    post_episode(occurred_on: "2025-04-06", pain_kind: "strong", intensity: 5)
    assert_response :unprocessable_entity
  end

  test "create cannot use another user's medication or trigger, and leaves nothing behind" do
    assert_no_difference ["Episode.count", "MedicationIntake.count", "EpisodeTrigger.count"] do
      post_episode(occurred_on: "2025-04-07", pain_kind: "migraine", intensity: 5,
                   medication_intakes_attributes: [{ medication_id: medications(:aspirin).id }])
      assert_response :unprocessable_entity

      post_episode(occurred_on: "2025-04-07", pain_kind: "migraine", intensity: 5, trigger_ids: [triggers(:other_users_trigger).id])
      assert_response :unprocessable_entity
    end
  end

  test "create ignores a user_id in the payload" do
    post_episode(occurred_on: "2025-04-08", pain_kind: "migraine", intensity: 5, user_id: users(:two).id)

    assert_response :created
    assert_equal @user.id, Episode.find(json_response[:data][:id]).user_id
  end

  test "create fails without authentication" do
    post "/api/v1/episodes", params: { occurred_on: "2025-04-09", aura: true }.to_json, headers: api_headers
    assert_response :unauthorized
  end

  # --- update / destroy -----------------------------------------------------

  test "update changes fields, intakes and triggers" do
    intake = medication_intakes(:first_dose)

    patch "/api/v1/episodes/#{@episode.id}",
      params: {
        intensity: 9, trigger_ids: [triggers(:sleep).id],
        medication_intakes_attributes: [{ id: intake.id, dose: "600 mg" }, { id: medication_intakes(:second_dose).id, _destroy: true }]
      }.to_json,
      headers: api_headers(authenticated_token)

    assert_response :success
    @episode.reload
    assert_equal 9, @episode.intensity
    assert_equal ["Lack of sleep"], @episode.triggers.map(&:name)
    assert_equal ["600 mg"], @episode.medication_intakes.map(&:dose)
  end

  test "update with invalid data changes nothing, including triggers" do
    patch "/api/v1/episodes/#{@episode.id}",
      params: { pain_kind: "", aura: false, trigger_ids: [] }.to_json,
      headers: api_headers(authenticated_token)

    assert_response :unprocessable_entity
    @episode.reload
    assert_equal "migraine", @episode.pain_kind
    assert_equal 2, @episode.triggers.count
  end

  test "update fails for another user's episode" do
    patch "/api/v1/episodes/#{episodes(:other_users).id}", params: { intensity: 1 }.to_json, headers: api_headers(authenticated_token)
    assert_response :not_found
  end

  test "destroy removes the episode with its intakes and trigger links" do
    assert_difference "Episode.count", -1 do
      delete "/api/v1/episodes/#{@episode.id}", headers: api_headers(authenticated_token)
    end
    assert_response :no_content
    assert_equal 0, MedicationIntake.where(episode_id: @episode.id).count
  end

  test "destroy fails for another user's episode" do
    assert_no_difference "Episode.count" do
      delete "/api/v1/episodes/#{episodes(:other_users).id}", headers: api_headers(authenticated_token)
    end
    assert_response :not_found
  end

  # --- calendar / yearly ----------------------------------------------------

  test "calendar groups episode ids by day" do
    month = @episode.occurred_on.strftime("%Y-%m")
    get "/api/v1/episodes/calendar", params: { month: month }, headers: api_headers(authenticated_token)

    assert_response :success
    by_day = json_response[:meta][:episodes_by_day]
    assert_equal 2, by_day[@episode.occurred_on.day.to_s.to_sym].length
  end

  test "calendar rejects a malformed month" do
    get "/api/v1/episodes/calendar", params: { month: "March" }, headers: api_headers(authenticated_token)
    assert_response :bad_request
  end

  test "yearly returns twelve months with counts" do
    get "/api/v1/episodes/yearly", params: { year: Date.current.year }, headers: api_headers(authenticated_token)

    assert_response :success
    meta = json_response[:meta]
    assert_equal 12, meta[:months].length
    assert_equal meta[:total_count], meta[:months].sum { |m| m[:count] }
  end
end
