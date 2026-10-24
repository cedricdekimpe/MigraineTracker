require "test_helper"

class TreatmentInsightsTest < ActiveSupport::TestCase
  setup do
    @user = User.create!({ email: "insights@example.com", password: "password123" }.merge(consent_attrs))
    @ibuprofen = @user.medications.create!(name: "Ibuprofen", kind: "acute")
    @triptan = @user.medications.create!(name: "Sumatriptan", kind: "triptan")
    @today = Date.new(2026, 10, 23)
  end

  def insights(**options)
    TreatmentInsights.new(@user, today: @today, **options)
  end

  def attack(date, medication: nil, effect: nil, started: "10:00", taken: "10:30", intensity: 6, pain: "migraine")
    episode = @user.episodes.create!(occurred_on: date, started_time: started, pain_kind: pain, intensity: intensity)
    episode.medication_intakes.create!(medication: medication, effect: effect, taken_time: taken) if medication
    episode
  end

  test "counts the effects noted for each medication, the most used first" do
    attack(@today - 5, medication: @ibuprofen, effect: "good")
    attack(@today - 4, medication: @ibuprofen, effect: "none")
    attack(@today - 3, medication: @ibuprofen)
    attack(@today - 2, medication: @triptan, effect: "partial")

    rows = insights.acute_rows
    assert_equal %w[Ibuprofen Sumatriptan], rows.map { |row| row.medication.name }
    assert_equal [3, 1, 1, 1], [rows.first.intakes, rows.first.good, rows.first.none, rows.first.unrated]
  end

  test "a drug that did nothing on 2 of the last 3 rated attacks is not working" do
    %w[good none none].each_with_index { |effect, i| attack(@today - 10 + i, medication: @ibuprofen, effect: effect) }
    assert_equal :not_working, insights.acute_rows.first.verdict
  end

  test "a drug that worked on 2 of 3 is working, and fewer than 3 rated attacks is too early" do
    %w[none good partial].each_with_index { |effect, i| attack(@today - 10 + i, medication: @ibuprofen, effect: effect) }
    assert_equal :working, insights.acute_rows.first.verdict

    attack(@today - 9, medication: @triptan, effect: "none")
    assert_equal :too_early, insights.acute_rows.find { |row| row.medication == @triptan }.verdict
  end

  test "only the last three rated attacks count for the verdict" do
    %w[none none good good good].each_with_index { |effect, i| attack(@today - 20 + i, medication: @ibuprofen, effect: effect) }
    assert_equal :working, insights.acute_rows.first.verdict
  end

  test "medications not taken for the attack are left out, and so is old history" do
    attack(@today - 5, medication: @user.medications.create!(name: "Metoclopramide", kind: "other"))
    attack(@today - 5, medication: @user.medications.create!(name: "Propranolol", kind: "preventive"))
    attack(@today - 800, medication: @ibuprofen, effect: "good")
    assert_empty insights.acute_rows
  end

  test "median delay before the first treatment" do
    attack(@today - 5, medication: @ibuprofen, started: "10:00", taken: "10:20")
    attack(@today - 4, medication: @ibuprofen, started: "10:00", taken: "11:00")
    attack(@today - 3, medication: @ibuprofen, started: "10:00", taken: "10:40")
    assert_equal({ minutes: 40, attacks: 3 }, insights.median_delay)
  end

  test "no delay without times" do
    attack(@today - 5, medication: @ibuprofen, started: nil)
    assert_nil insights.median_delay
  end

  test "a preventive is compared with the 90 days before it" do
    propranolol = @user.medications.create!(name: "Propranolol", kind: "preventive")
    start = Date.new(2026, 1, 1)
    # 9 pain days in the 90 days before, 3 in the last 90 days of the period
    (1..9).each { |i| attack(start - 10 * i, pain: "headache") }
    @user.episodes.create!(occurred_on: start - 95, pain_kind: "migraine", intensity: 5) # also before: keeps the journal covering the window
    period = propranolol.treatment_periods.create!(user: @user, started_on: start, ended_on: Date.new(2026, 6, 29))
    [Date.new(2026, 5, 1), Date.new(2026, 5, 20), Date.new(2026, 6, 10)].each { |date| attack(date) }

    row = insights.preventive_rows.first
    assert_equal period, row.period
    assert_equal [3.0, 1.0], [row.before, row.after]
    assert_equal 0.67, row.drop
    assert row.responder?
  end

  test "no comparison before 90 days on the treatment, or when the journal started late" do
    propranolol = @user.medications.create!(name: "Propranolol", kind: "preventive")
    propranolol.treatment_periods.create!(user: @user, started_on: @today - 30)
    attack(@today - 20)
    row = insights.preventive_rows.first
    assert_nil row.before # the journal only starts 20 days ago: nothing to compare with
    assert_nil row.after
    assert_not row.responder?
  end

  test "attacks around the first bleeding day, in at least 2 of the last 3 cycles" do
    starts = [Date.new(2026, 7, 10), Date.new(2026, 8, 7), Date.new(2026, 9, 4)]
    starts.each { |start| 4.times { |i| @user.period_days.create!(date: start + i) } }
    attack(starts[0] - 1)
    attack(starts[1] + 2)

    link = insights.menstrual_link
    assert_equal [3, 2, 0], [link.cycles, link.with_attack, link.outside_attacks]
    assert link.pattern?
    assert link.pure?
  end

  test "an attack at another time of the cycle means it is not purely menstrual" do
    starts = [Date.new(2026, 7, 10), Date.new(2026, 8, 7), Date.new(2026, 9, 4)]
    starts.each { |start| @user.period_days.create!(date: start) }
    attack(starts[0]); attack(starts[1]); attack(starts[1] + 14)

    link = insights.menstrual_link
    assert link.pattern?
    assert_not link.pure?
    assert_equal 1, link.outside_attacks
  end

  test "fewer than 3 cycles is not a pattern, and no period days means nothing to say" do
    assert_nil insights.menstrual_link
    @user.period_days.create!(date: Date.new(2026, 9, 4))
    attack(Date.new(2026, 9, 4))
    assert_not insights.menstrual_link.pattern?
  end

  test "other users' data is never used" do
    other = users(:two)
    other.period_days.create!(date: Date.new(2026, 9, 4))
    assert_nil insights.menstrual_link
    assert_empty insights.acute_rows
  end

  test "nausea is summed over the painful attacks that answered, from three of them" do
    attack(@today - 5).update!(nausea: "none")
    attack(@today - 4).update!(nausea: "nausea")
    assert_nil insights.nausea, "two answers are too few"

    attack(@today - 3).update!(nausea: "vomiting")
    attack(@today - 2) # not answered: left out
    aura_only = @user.episodes.create!(occurred_on: @today - 1, aura: true, nausea: "nausea")

    summary = insights.nausea
    assert_equal [ 3, 2, 1 ], [ summary.rated, summary.with_nausea, summary.vomiting ]
    assert aura_only.persisted?
  end
end
