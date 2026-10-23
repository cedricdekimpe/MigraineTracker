# frozen_string_literal: true

require "test_helper"

class Api::V1::DataControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @user = users(:one)
    @token = nil
  end

  def authenticated_token
    @token ||= login_user(@user.email, "password123")
  end

  # ===============
  # Export
  # ===============

  test "export returns all user data in the v2 format" do
    get "/api/v1/data/export", headers: api_headers(authenticated_token)

    assert_response :success
    assert_json_api_resource("export")

    attrs = json_response[:data][:attributes]
    assert_equal DataExporter::FORMAT_VERSION, attrs[:format_version]
    assert_equal @user.email, attrs[:user_email]
    assert_equal @user.medications.count, attrs[:medications].length
    assert_equal @user.triggers.count, attrs[:triggers].length
    assert_equal @user.episodes.count, attrs[:episodes].length
    assert_equal @user.episodes.count, json_response[:meta][:episodes_count]
  end

  test "export includes aura, intakes, triggers and archived medications" do
    get "/api/v1/data/export", headers: api_headers(authenticated_token)

    attrs = json_response[:data][:attributes]
    episode = attrs[:episodes].find { |e| e[:started_time] == "08:30" }
    assert_equal true, episode[:aura]
    assert_equal "migraine", episode[:pain_kind]
    assert_equal ["Lack of sleep", "Stress"], episode[:triggers]
    ibuprofen = episode[:medications].find { |m| m[:name] == "Ibuprofen" }
    assert_equal ["400 mg", "08:45", "partial"], [ibuprofen[:dose], ibuprofen[:taken_time], ibuprofen[:effect]]
    assert_equal true, attrs[:medications].find { |m| m[:name] == "Old Med" }[:archived]
  end

  test "export only contains the user's own data" do
    get "/api/v1/data/export", headers: api_headers(authenticated_token)

    assert_not_includes json_response[:data][:attributes][:medications].map { |m| m[:name] }, "Aspirin"
    assert_equal 4, json_response[:data][:attributes][:episodes].length
  end

  test "export fails without authentication" do
    get "/api/v1/data/export", headers: api_headers
    assert_response :unauthorized
  end

  # ===============
  # Import
  # ===============

  def post_import(data = nil, token: authenticated_token, **attributes)
    payload = (data || {}).merge(attributes)
    post "/api/v1/data/import", params: { data: payload }.to_json, headers: api_headers(token)
  end

  test "import creates medications, triggers and episodes" do
    new_user = User.create!({ email: "import_test@example.com", password: "password123" }.merge(consent_attrs))
    token = login_user(new_user.email, "password123")
    new_user.triggers.destroy_all

    assert_difference ["new_user.medications.count", "new_user.triggers.count"], 1 do
      assert_difference "new_user.episodes.count", 2 do
        post_import({
          user_email: new_user.email,
          medications: [{ name: "Imported Med", kind: "preventive", default_dose: "10 mg" }],
          triggers: [{ name: "Noise" }],
          episodes: [
            { occurred_on: "2024-01-10", started_time: "06:30", aura: true, pain_kind: "migraine", intensity: 6,
              triggers: ["Noise"], medications: [{ name: "Imported Med", dose: "10 mg", effect: "good" }] },
            { occurred_on: "2024-01-10", aura: true }
          ]
        }, token: token)
      end
    end

    assert_response :success
    assert_json_api_resource("import_result")
    attrs = json_response[:data][:attributes]
    assert_equal [1, 1, 2], [attrs[:medications_imported], attrs[:triggers_imported], attrs[:episodes_imported]]

    episode = new_user.episodes.find_by!(started_time: "06:30")
    assert_equal ["Noise"], episode.triggers.map(&:name)
    assert_equal "preventive", new_user.medications.find_by!(name: "Imported Med").kind
  end

  test "importing your own export again does not duplicate anything" do
    get "/api/v1/data/export", headers: api_headers(authenticated_token)
    exported = json_response[:data][:attributes]

    assert_no_difference ["@user.episodes.count", "@user.medications.count", "@user.triggers.count"] do
      post_import(exported.except(:exported_at))
    end
    assert_response :success
    assert_equal 0, json_response[:data][:attributes][:episodes_imported]
  end

  test "import does not un-archive existing medications" do
    post_import(episodes: [{ occurred_on: "2024-02-01", pain_kind: "headache", intensity: 2, medications: [{ name: "Old Med" }] }])

    assert_response :success
    assert medications(:old_med).reload.archived?
  end

  test "import fails with mismatched email" do
    post_import(user_email: "different@example.com", medications: [], episodes: [])

    assert_response :unprocessable_entity
    assert json_response[:errors].present?
    assert_no_match(/different@example.com/, json_response[:errors].first[:detail])
  end

  test "import is all-or-nothing and reports the faulty row" do
    assert_no_difference ["@user.episodes.count", "@user.medications.count"] do
      post_import(
        medications: [{ name: "Never Created" }],
        episodes: [
          { occurred_on: (Date.current - 200.days).iso8601, pain_kind: "migraine", intensity: 3 },
          { occurred_on: "not-a-date", pain_kind: "migraine", intensity: 3 }
        ]
      )
    end

    assert_response :unprocessable_entity
    assert_match(/Episode #2/, json_response[:errors].first[:detail])
  end

  test "import reports episodes that break the aura-or-pain rule" do
    post_import(episodes: [{ occurred_on: "2024-03-01" }])

    assert_response :unprocessable_entity
    assert_match(/Episode #1/, json_response[:errors].first[:detail])
  end

  test "import rejects malformed collections" do
    [{ episodes: "nope" }, { episodes: ["2020-01-01"] }, { episodes: [], medications: "x" }, { episodes: [], triggers: ["Stress"] }].each do |payload|
      post_import(payload)
      assert_response :unprocessable_entity, "expected #{payload.inspect} to be rejected"
    end
  end

  test "import ignores unknown attributes instead of mass-assigning them" do
    post_import(episodes: [{ occurred_on: (Date.current - 300.days).iso8601, pain_kind: "migraine", intensity: 4, user_id: users(:two).id, id: 1 }])

    assert_response :success
    assert @user.episodes.exists?(occurred_on: Date.current - 300.days)
    assert_not users(:two).episodes.exists?(occurred_on: Date.current - 300.days)
  end

  test "import rejects oversized payloads" do
    big = { data: { episodes: [], padding: "x" * (Api::V1::DataController::MAX_IMPORT_BYTES + 1) } }
    post "/api/v1/data/import", params: big.to_json, headers: api_headers(authenticated_token)
    assert_response :content_too_large
  end

  test "import fails without authentication" do
    post "/api/v1/data/import", params: { data: {} }.to_json, headers: api_headers
    assert_response :unauthorized
  end
end
