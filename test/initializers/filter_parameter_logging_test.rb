require "test_helper"

# Health data must never be written to the logs: every parameter a form or a one-tap screen sends.
class FilterParameterLoggingTest < ActiveSupport::TestCase
  def filtered(params)
    ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(params)
  end

  test "episode, check-in, treatment period, medication and trigger forms are filtered whole" do
    params = {
      episode: { pain_kind: "migraine", aura: "1", notes: "nausea", new_trigger_names: "chocolate" },
      daily_check: { sleep: "short", stress: "high" },
      treatment_period: { started_on: "2026-01-01", stop_reason: "not_tolerated" },
      medication: { name: "Topiramate", kind: "preventive" },
      trigger: { name: "Chocolate" }
    }
    filtered(params).each_value { |value| assert_equal "[FILTERED]", value }
  end

  test "the loose parameters of the crisis screens, the effect and period answers, the import file" do
    params = { pain_kind: "migraine", intensity: "7", aura_only: "1", name: "Topiramate", kind: "triptan",
               effect: "none", period: "yes", date: "2026-10-23", file: "backup.json" }
    filtered(params).each { |key, value| assert_equal "[FILTERED]", value, "#{key} reached the logs" }
  end

  test "navigation parameters stay readable" do
    assert_equal({ locale: "fr", month: "2026-10", year: "2026" }, filtered({ locale: "fr", month: "2026-10", year: "2026" }))
  end
end
