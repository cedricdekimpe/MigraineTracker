require "test_helper"

class ImportsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
  end

  def upload(content, filename: "export.json")
    Rack::Test::UploadedFile.new(StringIO.new(content.is_a?(String) ? content : content.to_json), "application/json", original_filename: filename)
  end

  def import(data)
    post imports_path, params: { file: upload(data) }
  end

  test "should require authentication" do
    sign_out @user
    get new_import_path
    assert_redirected_to new_user_session_path

    post imports_path
    assert_redirected_to new_user_session_path
  end

  test "shows the upload form" do
    get new_import_path
    assert_response :success
    assert_select "input[type=file]"
  end

  test "rejects a request without file" do
    post imports_path
    assert_redirected_to new_import_path
    assert_equal I18n.t("flash.export_file_missing"), flash[:alert]
  end

  test "rejects a file field that is not an uploaded file" do
    post imports_path, params: { file: "not-a-file" }
    assert_redirected_to new_import_path
    assert_equal I18n.t("flash.export_file_missing"), flash[:alert]
  end

  test "rejects invalid JSON" do
    post imports_path, params: { file: upload("{ nope", filename: "bad.json") }
    assert_redirected_to new_import_path
    assert_match(/Invalid JSON/, flash[:alert])
  end

  test "rejects JSON nested too deeply" do
    post imports_path, params: { file: upload(("[" * 50) + ("]" * 50)) }
    assert_redirected_to new_import_path
    assert_match(/Invalid JSON/, flash[:alert])
  end

  test "rejects files above the size limit" do
    big = "{" + " " * (ImportsController::MAX_FILE_SIZE + 1) + "}"
    assert_no_difference "@user.episodes.count" do
      post imports_path, params: { file: upload(big) }
    end
    assert_redirected_to new_import_path
    assert_match(/too large/, flash[:alert])
  end

  test "rejects JSON that is not a backup" do
    import([ 1, 2, 3 ])
    assert_redirected_to new_import_path
    assert_match(/valid backup data/, flash[:alert])
  end

  test "rejects a backup of another account without echoing nothing sensitive" do
    import(user_email: "someone@else.com", episodes: [])
    assert_redirected_to new_import_path
    assert_match(/does not match your account/, flash[:alert])
  end

  test "imports medications, triggers and episodes" do
    assert_difference "@user.medications.count", 1 do
      assert_difference "@user.triggers.count", 1 do
        assert_difference "@user.episodes.count", 1 do
          import(
            user_email: @user.email,
            medications: [ { name: "Sumatriptan", kind: "acute", default_dose: "50 mg" } ],
            triggers: [ { name: "Noise" } ],
            episodes: [ { occurred_on: "2024-05-05", aura: true, pain_kind: "migraine", intensity: 8, triggers: [ "Noise" ],
                         medications: [ { name: "Sumatriptan", dose: "50 mg", taken_time: "10:00", effect: "good" } ] } ]
          )
        end
      end
    end

    assert_redirected_to edit_user_registration_path
    assert_equal "Successfully imported 1 medications and 1 episodes.", flash[:notice]

    episode = @user.episodes.find_by!(occurred_on: "2024-05-05")
    assert episode.aura?
    assert_equal [ "Noise" ], episode.triggers.map(&:name)
    assert_equal "10:00", episode.medication_intakes.first.taken_time.strftime("%H:%M")
  end

  test "skips episodes that are already there but accepts a second one the same day" do
    existing = episodes(:headache)
    row = { occurred_on: existing.occurred_on.iso8601, pain_kind: "headache", intensity: 4 }

    assert_difference "@user.episodes.count", 1 do
      import(episodes: [ row, row.merge(started_time: "22:00") ])
    end
    assert_equal "Successfully imported 0 medications and 1 episodes.", flash[:notice]
  end

  test "matches existing medications ignoring case" do
    assert_no_difference "@user.medications.count" do
      import(episodes: [ { occurred_on: "2024-06-01", pain_kind: "migraine", intensity: 5, medications: [ { name: "ibuprofen" } ] } ])
    end
    assert_equal medications(:ibuprofen), @user.episodes.find_by!(occurred_on: "2024-06-01").medications.first
  end

  test "rolls back everything on an invalid row" do
    assert_no_difference [ "@user.episodes.count", "@user.medications.count", "@user.triggers.count" ] do
      import(
        medications: [ { name: "Brand New" } ],
        triggers: [ { name: "Brand New" } ],
        episodes: [ { occurred_on: "2024-07-01", aura: true }, { occurred_on: "invalid-date", pain_kind: "migraine", intensity: 5 } ]
      )
    end

    assert_redirected_to new_import_path
    assert_match(/Error importing data: Episode #2/, flash[:alert])
  end

  test "error messages never leak exception details" do
    import(episodes: [ { occurred_on: "31/12/2020", pain_kind: "migraine", intensity: 3 } ])

    assert_match(/Episode #1/, flash[:alert])
    assert_no_match(/Date::Error|ActiveRecord|NoMethodError|Validation failed/, flash[:alert])
  end
end
