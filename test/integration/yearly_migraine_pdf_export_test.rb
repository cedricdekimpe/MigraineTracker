require "test_helper"

class YearlyMigrainePdfExportTest < ActionDispatch::IntegrationTest
  test "signed in user can download yearly migraine pdf" do
    user = User.create!({
      email: "export@example.com",
      password: "password123",
      password_confirmation: "password123"
    }.merge(consent_attrs))
    medication = user.medications.first
    user.migraines.create!(occurred_on: Date.new(2025, 5, 12), nature: "M", intensity: 7, on_period: false, medication: medication)

    post user_session_path, params: { user: { email: user.email, password: "password123" } }
    follow_redirect!
    get yearly_migraines_path(format: :pdf, year: 2025)

    assert_response :success
    assert_equal "application/pdf", @response.media_type
    assert_includes @response.get_header("Content-Disposition"), "attachment"
    assert @response.body.start_with?("%PDF"), "Expected PDF response body"
  end
end
