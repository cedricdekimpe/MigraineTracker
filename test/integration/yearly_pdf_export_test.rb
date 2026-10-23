require "test_helper"

class YearlyPdfExportTest < ActionDispatch::IntegrationTest
  def sign_in_with_data(track_cycle: false)
    user = User.create!({
      email: "export@example.com",
      password: "password123",
      password_confirmation: "password123",
      track_cycle: track_cycle
    }.merge(consent_attrs))
    medication = user.medications.create!(name: "Ibuprofen")
    episode = user.episodes.create!(occurred_on: Date.new(2025, 5, 12), pain_kind: "migraine", aura: true, intensity: 7)
    episode.medication_intakes.create!(medication: medication)
    user.episodes.create!(occurred_on: Date.new(2025, 5, 12), aura: true) # second episode the same day

    post user_session_path, params: { user: { email: user.email, password: "password123" } }
    follow_redirect!
  end

  test "signed in user can download the yearly pdf" do
    sign_in_with_data
    get yearly_episodes_path(format: :pdf, year: 2025)

    assert_response :success
    assert_equal "application/pdf", @response.media_type
    assert_includes @response.get_header("Content-Disposition"), "attachment"
    assert @response.body.start_with?("%PDF"), "Expected PDF response body"
  end

  test "pdf also renders with cycle tracking enabled" do
    sign_in_with_data(track_cycle: true)
    get yearly_episodes_path(format: :pdf, year: 2025)

    assert_response :success
    assert @response.body.start_with?("%PDF")
  end

  test "pdf requires authentication" do
    get yearly_episodes_path(format: :pdf, year: 2025)
    assert_response :unauthorized
  end
end
