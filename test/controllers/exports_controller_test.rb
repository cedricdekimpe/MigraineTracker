require "test_helper"

class ExportsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
  end

  def exported
    JSON.parse(response.body)
  end

  test "should require authentication" do
    sign_out @user
    post exports_path
    assert_redirected_to new_user_session_path
  end

  test "downloads a JSON attachment named after the user and timestamp" do
    post exports_path

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert_match(/migraine_data_#{@user.id}_\d{8}_\d{6}\.json/, response.headers["Content-Disposition"])
  end

  test "contains version, timestamp and email" do
    post exports_path

    assert_equal DataExporter::FORMAT_VERSION, exported["format_version"]
    assert_equal @user.email, exported["user_email"]
    assert_nothing_raised { Time.iso8601(exported["exported_at"]) }
  end

  test "exports every medication, trigger and episode of the user" do
    post exports_path

    assert_equal @user.medications.pluck(:name).sort, exported["medications"].map { |m| m["name"] }.sort
    assert_equal @user.triggers.pluck(:name).sort, exported["triggers"].map { |t| t["name"] }.sort
    assert_equal @user.episodes.count, exported["episodes"].length
  end

  test "episodes carry aura, pain, time, intakes and triggers" do
    post exports_path

    episode = exported["episodes"].find { |e| e["started_time"] == "08:30" }
    assert_equal [true, "migraine", 7, 240], episode.values_at("aura", "pain_kind", "intensity", "duration_minutes")
    assert_equal ["Lack of sleep", "Stress"], episode["triggers"]
    assert_equal ["Ibuprofen", "Paracetamol"], episode["medications"].map { |m| m["name"] }.sort

    aura_only = exported["episodes"].find { |e| e["aura"] && e["pain_kind"].nil? }
    assert_nil aura_only["intensity"]
  end

  test "does not include another user's data" do
    post exports_path

    assert_not_includes exported["medications"].map { |m| m["name"] }, "Aspirin"
    assert_not_includes exported["episodes"].map { |e| e["occurred_on"] }, episodes(:other_users).occurred_on.iso8601
  end

  test "an empty account exports empty lists" do
    sign_in User.create!({ email: "empty@example.com", password: "password123" }.merge(consent_attrs)).tap { |u| u.triggers.destroy_all }
    post exports_path

    assert_equal [], exported["episodes"]
    assert_equal [], exported["medications"]
  end

  test "export can be imported back into a fresh account" do
    post exports_path
    backup = response.body

    fresh = User.create!({ email: "fresh@example.com", password: "password123" }.merge(consent_attrs))
    result = DataImporter.new(fresh, JSON.parse(backup.sub(@user.email, fresh.email))).call

    assert_equal @user.episodes.count, result.episodes
    assert_equal @user.episodes.count, fresh.episodes.count
    assert_equal MedicationIntake.where(episode: @user.episodes).count, MedicationIntake.where(episode: fresh.episodes).count
    assert_equal @user.episodes.joins(:triggers).count, fresh.episodes.joins(:triggers).count
  end
end
