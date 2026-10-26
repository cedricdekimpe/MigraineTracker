require "test_helper"

class TreatmentPeriodsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
    @medication = medications(:candesartan)
  end

  def params_for(**attributes)
    { treatment_period: { started_on: "2026-01-01" }.merge(attributes) }
  end

  test "adds a period" do
    assert_difference -> { @medication.treatment_periods.count }, 1 do
      post medication_treatment_periods_path(medication_id: @medication.id), params: params_for(dose: "16 mg")
    end
    assert_redirected_to account_medications_path(open: @medication.id, anchor: "medication-#{@medication.id}")
    assert_equal "16 mg", @medication.treatment_periods.first.dose
    assert_equal @user, @medication.treatment_periods.first.user
  end

  test "stops a period with a reason" do
    period = @medication.treatment_periods.create!(user: @user, started_on: "2026-01-01")
    patch medication_treatment_period_path(medication_id: @medication.id, id: period.id), params: { treatment_period: { ended_on: "2026-04-01", stop_reason: "ineffective" } }
    assert_equal [ "2026-04-01", "ineffective" ], [ period.reload.ended_on.iso8601, period.stop_reason ]
  end

  test "an invalid period is refused with a message" do
    assert_no_difference -> { TreatmentPeriod.count } do
      post medication_treatment_periods_path(medication_id: @medication.id), params: params_for(ended_on: "2025-01-01")
    end
    follow_redirect!
    assert_match(/avant|before/i, response.body)
  end

  test "deletes a period" do
    period = @medication.treatment_periods.create!(user: @user, started_on: "2026-01-01")
    assert_difference -> { TreatmentPeriod.count }, -1 do
      delete medication_treatment_period_path(medication_id: @medication.id, id: period.id)
    end
  end

  test "another user's medication cannot be given periods" do
    other = users(:two).medications.create!(name: "Topiramate", kind: "preventive")
    assert_no_difference -> { TreatmentPeriod.count } do
      post medication_treatment_periods_path(medication_id: other.id), params: params_for
    end
    assert_response :not_found
  end

  test "the medications page shows periods for preventives only" do
    @medication.treatment_periods.create!(user: @user, started_on: "2026-01-01", ended_on: "2026-04-01", stop_reason: "not_tolerated", dose: "16 mg")
    get account_medications_path
    assert_select "li#medication-#{@medication.id} [data-treatment-periods] [data-period]", 1
    assert_select "li#medication-#{medications(:ibuprofen).id} [data-treatment-periods]", count: 0
  end

  test "requires authentication" do
    sign_out @user
    post medication_treatment_periods_path(medication_id: @medication.id), params: params_for
    assert_redirected_to new_user_session_path
  end
end
