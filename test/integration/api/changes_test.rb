require "test_helper"

class Api::ChangesTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    _device, @token = ApiToken.issue(@user, name: "Phone")
    # The fixtures were just saved: inside the feed's overlap window of any cursor taken now
    Episode.update_all(updated_at: 1.hour.ago)
  end

  def headers = { "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json" }

  def pull(since = nil)
    get api_v1_changes_path, params: { since: since }.compact, headers: headers
    assert_response :success
    response.parsed_body
  end

  def push(body)
    post api_v1_changes_path, params: body.to_json, headers: headers
    assert_response :success
    response.parsed_body["results"]
  end

  def new_uuid = SecureRandom.uuid

  test "the first pull sends the whole journal, with the medications and triggers" do
    feed = pull
    assert feed["full"]
    assert_equal @user.episodes.count, feed["episodes"].size
    episode = feed["episodes"].find { |e| e["uuid"] == episodes(:migraine_with_aura).reload.uuid }
    assert_equal "08:30", episode["started_time"]
    assert_equal 2, episode["medication_intakes"].size
    assert_equal @user.medications.count, feed["medications"].size
    assert Time.iso8601(feed["cursor"])
  end

  test "another account's journal never shows" do
    other = Episode.create!(user: users(:two), occurred_on: Date.current, pain_kind: "headache", intensity: 3)
    assert_not pull["episodes"].any? { |e| e["uuid"] == other.uuid }
  end

  test "a later pull only sends what changed since the cursor, deletions included" do
    cursor = pull["cursor"]
    travel 1.minute do
      episodes(:headache).update!(intensity: 6)
      episodes(:migraine_with_aura).destroy!
      feed = pull(cursor)
      assert_not feed["full"]
      assert_equal [ episodes(:headache).uuid ], feed["episodes"].map { |e| e["uuid"] }
      assert_equal [ { "type" => "episode", "uuid" => episodes(:migraine_with_aura).uuid } ],
        feed["deletions"].map { |d| d.slice("type", "uuid") }
    end
  end

  test "changing an intake on the web changes its episode for the app" do
    cursor = pull["cursor"]
    travel 1.minute do
      medication_intakes(:first_dose).update!(effect: "good")
      assert_includes pull(cursor)["episodes"].map { |e| e["uuid"] }, episodes(:migraine_with_aura).uuid
    end
  end

  test "an episode made offline is created once, even when sent twice" do
    uuid = new_uuid
    intake = new_uuid
    item = { uuid: uuid, occurred_on: Date.current.iso8601, started_time: "07:15", pain_kind: "migraine", intensity: 8,
             medication_intakes: [ { uuid: intake, medication_id: medications(:ibuprofen).id, taken_time: "07:30" } ],
             updated_at: 1.minute.ago.iso8601(6) }

    assert_difference -> { @user.episodes.count }, 1 do
      assert_equal "saved", push(episodes: [ item ]).first["status"]
      push(episodes: [ item ])
    end
    episode = @user.episodes.find_by!(uuid: uuid)
    assert_equal "07:15", episode.started_time.strftime("%H:%M")
    assert_equal [ intake ], episode.medication_intakes.map(&:uuid)
  end

  test "the intakes sent replace the episode's intakes" do
    episode = episodes(:migraine_with_aura).reload
    kept = medication_intakes(:first_dose).reload.uuid
    push(episodes: [ { uuid: episode.uuid, occurred_on: episode.occurred_on.iso8601, pain_kind: "migraine", intensity: 7, aura: true,
                       medication_intakes: [ { uuid: kept, medication_id: medications(:ibuprofen).id, effect: "good" } ],
                       updated_at: Time.current.iso8601(6) } ])
    assert_equal [ kept ], episode.reload.medication_intakes.map(&:uuid)
    assert_equal "good", episode.medication_intakes.first.effect
  end

  test "an edit older than the server's copy is not applied" do
    episode = episodes(:headache)
    episode.update!(intensity: 5)
    results = push(episodes: [ { uuid: episode.uuid, occurred_on: episode.occurred_on.iso8601, pain_kind: "headache", intensity: 2,
                                 updated_at: 1.hour.ago.iso8601(6) } ])
    assert_equal "stale", results.first["status"]
    assert_equal 5, episode.reload.intensity
  end

  test "invalid records come back with codes and do not stop the others" do
    good = new_uuid
    results = push(episodes: [
      { uuid: new_uuid, occurred_on: (Date.current + 3).iso8601, pain_kind: "migraine", intensity: 4 },
      { uuid: new_uuid, occurred_on: Date.current.iso8601, pain_kind: "migraine" },
      { uuid: "not-a-uuid", occurred_on: Date.current.iso8601, aura: true },
      { uuid: good, occurred_on: Date.current.iso8601, aura: true }
    ])
    assert_equal %w[invalid invalid invalid saved], results.map { |r| r["status"] }
    assert_equal [ "future" ], results[0]["errors"]["occurred_on"]
    assert_equal [ "blank" ], results[1]["errors"]["intensity"]
    assert @user.episodes.exists?(uuid: good)
  end

  test "another account's medication or uuid cannot be used" do
    theirs = Episode.create!(user: users(:two), occurred_on: Date.current, aura: true)
    foreign_medication = Medication.create!(user: users(:two), name: "Theirs", kind: "acute")
    results = push(episodes: [
      { uuid: theirs.uuid, occurred_on: Date.current.iso8601, aura: true },
      { uuid: new_uuid, occurred_on: Date.current.iso8601, aura: true,
        medication_intakes: [ { uuid: new_uuid, medication_id: foreign_medication.id } ] }
    ])
    assert_equal %w[invalid invalid], results.map { |r| r["status"] }
    assert_equal [ "taken" ], results[0]["errors"]["uuid"]
    assert theirs.reload.aura?
  end

  test "a day marked on two devices stays one day" do
    @user.update!(track_cycle: true)
    day = @user.period_days.create!(date: Date.current - 1)
    results = push(period_days: [ { uuid: new_uuid, date: day.date.iso8601 } ])
    assert_equal "merged", results.first["status"]
    assert_equal day.uuid, results.first["uuid_now"]
    assert_equal 1, @user.period_days.where(date: day.date).count
  end

  test "a check-in of a day already checked elsewhere updates that check-in" do
    check = @user.daily_checks.create!(date: Date.current, sleep: "good")
    travel 1.minute do
      results = push(daily_checks: [ { uuid: new_uuid, date: Date.current.iso8601, sleep: "short", stress: "high", updated_at: Time.current.iso8601(6) } ])
      assert_equal "merged", results.first["status"]
      assert_equal check.uuid, results.first["uuid_now"]
      assert_equal %w[short high], check.reload.attributes.values_at("sleep", "stress")
    end
  end

  test "a deletion from the phone deletes, unless the record changed afterwards" do
    gone = episodes(:headache)
    changed = episodes(:migraine_with_aura)
    changed.touch
    results = push(deletions: [
      { type: "episode", uuid: gone.uuid, deleted_at: Time.current.iso8601(6) },
      { type: "episode", uuid: changed.uuid, deleted_at: 1.hour.ago.iso8601(6) },
      { type: "episode", uuid: new_uuid, deleted_at: Time.current.iso8601(6) },
      { type: "user", uuid: new_uuid }
    ])
    assert_equal %w[deleted stale gone invalid], results.map { |r| r["status"] }
    assert_not Episode.exists?(gone.id)
    assert Episode.exists?(changed.id)
    assert @user.deletions.exists?(uuid: gone.uuid)
  end

  test "too many records at once are refused" do
    post api_v1_changes_path, params: { period_days: Array.new(501) { { uuid: new_uuid, date: Date.current.iso8601 } } }.to_json, headers: headers
    assert_response :content_too_large
  end

  test "a malformed cursor is a bad request" do
    get api_v1_changes_path, params: { since: "yesterday" }, headers: headers
    assert_response :bad_request
  end
end
