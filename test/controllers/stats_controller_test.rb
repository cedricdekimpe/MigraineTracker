require "test_helper"

class StatsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @today = Time.zone.local(2026, 10, 23, 12, 0)
    @user = User.create!({ email: "stats@example.com", password: "password123" }.merge(consent_attrs))
    @triptan = @user.medications.create!(name: "Sumatriptan", kind: "triptan")
    @acute = @user.medications.create!(name: "Ibuprofen", kind: "acute")
  end

  def log(date, pain: "migraine", aura: false, medications: [], triggers: [])
    episode = @user.episodes.create!(occurred_on: date, pain_kind: pain, aura: aura, intensity: pain ? 5 : nil)
    medications.each { |medication| episode.medication_intakes.create!(medication: medication) }
    episode.triggers = triggers
    episode
  end

  def visit_stats(locale: nil)
    sign_in @user
    travel_to(@today) { get stats_path(locale: locale) }
  end

  def figure(name)
    css_select("[data-figure='#{name}']").first&.text&.strip
  end

  test "requires authentication" do
    get stats_path
    assert_redirected_to new_user_session_path
  end

  test "an empty account gets an invitation instead of empty charts" do
    visit_stats

    assert_response :success
    assert_match(/Nothing to show yet/, response.body)
    assert_select "[data-chart]", count: 0
    assert_select "a[href='#{now_path}']"
  end

  test "this month: days with pain, migraine days, treatment days and the 3-month average" do
    log(Date.new(2026, 10, 5), medications: [ @triptan ])
    log(Date.new(2026, 10, 5)) # same day, still one day
    log(Date.new(2026, 10, 6), pain: "headache", medications: [ @acute ])
    [ Date.new(2026, 7, 1), Date.new(2026, 8, 1), Date.new(2026, 8, 2), Date.new(2026, 9, 1), Date.new(2026, 9, 2), Date.new(2026, 9, 3) ].each { |d| log(d) }
    visit_stats

    assert_equal "2", figure("pain-days")
    assert_equal "2", figure("acute-days")
    assert_equal "2", figure("average")
    assert_select "[data-month-summary]", text: /octobre 2026|October 2026/i
    assert_match(/of which 1 migraine/, response.body)
    assert_match(/1 with a triptan, 1 with another treatment/, response.body)
  end

  test "the average shows a dash until a complete month exists" do
    log(Date.new(2026, 10, 5))
    visit_stats

    assert_equal "–", figure("average")
    assert_match(/not enough complete months yet/, response.body)
  end

  test "the month panel takes the ink of the month, like the paper calendar" do
    log(Date.new(2026, 10, 5))
    visit_stats
    assert_select "[data-month-summary].bg-panel-amber.border-amber-400" # October = first ink of its quarter

    @today = Time.zone.local(2026, 11, 20)
    travel_to(@today) { log(Date.new(2026, 11, 2)) } # a date of the journal only once November has come
    visit_stats
    assert_select "[data-month-summary].bg-panel-rose.border-rose-400"
  end

  test "treatment meters stay calm below the thresholds" do
    3.times { |i| log(Date.new(2026, 10, i + 1), medications: [ @triptan ]) }
    visit_stats

    assert_select "[data-overuse=ok]"
    assert_select "[data-meter=triptan] [role=meter][aria-valuenow='3'][aria-valuemax='10']"
    assert_select "[data-meter=triptan] .bg-meter-ok"
    assert_match(/Below the advised limits\./, response.body)
  end

  test "treatment meters warn near and at the thresholds" do
    8.times { |i| log(Date.new(2026, 10, i + 1), medications: [ @triptan ]) }
    visit_stats
    assert_select "[data-overuse=advised]"
    assert_select "[data-meter=triptan] .bg-meter-advised"
    assert_match(/Above the advised limits/, response.body)

    2.times { |i| log(Date.new(2026, 10, i + 9), medications: [ @triptan ]) }
    visit_stats
    assert_select "[data-overuse=over]"
    assert_select "[data-meter=triptan] .bg-meter-over"
    assert_match(/Threshold reached this month/, response.body)
  end

  test "a meter marks the advised limit and a heavy week is mentioned" do
    (5..7).each { |day| log(Date.new(2026, 10, day), medications: [ @triptan ]) }
    visit_stats

    assert_select "[data-meter=triptan] [role=meter] span[style*='left: 80%']"
    assert_select "[data-heavy-weeks]"
  end

  test "the threshold three months in a row is spelled out" do
    [ Date.new(2026, 8, 1), Date.new(2026, 9, 1), Date.new(2026, 10, 1) ].each do |month|
      10.times { |i| log(month + i, medications: [ @triptan ]) }
    end
    visit_stats

    assert_select "[data-overuse=sustained]"
    assert_match(/Threshold reached 3 months in a row/, response.body)
  end

  test "mixing both kinds shows the combined count" do
    5.times { |i| log(Date.new(2026, 10, i + 1), medications: [ @triptan ]) }
    5.times { |i| log(Date.new(2026, 10, i + 6), medications: [ @acute ]) }
    visit_stats

    assert_select "[data-overuse=over]"
    assert_match(/Several kinds together: 10 days/, response.body)
  end

  test "twelve months of columns, two series told apart by lightness, with the threshold on the treatment chart" do
    log(Date.new(2026, 10, 5), medications: [ @acute ])
    visit_stats

    assert_select "[data-chart=pain-days] svg[role=img]", count: 2 # wide and phone versions
    assert_select "[data-chart=pain-days] .sm\\:hidden svg g rect", count: 1 # only October has a column
    assert_select "[data-chart=pain-days] .sm\\:hidden svg text", text: "O" # one-letter months on phones
    assert_select "[data-chart=pain-days] svg text", text: /oct|Oct/
    assert_select "[data-chart=acute-days] svg line[style*='stroke-dasharray']", count: 2
    assert_select "[data-chart=acute-days] svg text", text: "10 days", count: 2
    assert_select "[data-chart=pain-days] svg rect[style*='--chart-a']" # migraine days, the strong series
    assert_select "[data-chart=pain-days] svg rect[style*='--amber-']", count: 0 # month inks never encode data
  end

  test "an accessible table backs the chart" do
    log(Date.new(2026, 10, 5))
    visit_stats

    assert_select "table.sr-only tbody tr", count: 12
  end

  test "auras alone are mentioned without inflating the pain days" do
    log(Date.new(2026, 10, 5), pain: nil, aura: true)
    log(Date.new(2026, 10, 6))
    visit_stats

    assert_equal "1", figure("pain-days")
    assert_match(/Plus 1 day with an aura only/, response.body)
  end

  test "the check-in invitation shows until there are enough days" do
    log(Date.new(2026, 10, 5))
    visit_stats
    assert_select "[data-daily-factors] a[href=?]", check_path
    assert_select "[data-daily-factors]", text: /0\/30 days/
    assert_select "[data-triggers]", count: 0
  end

  test "once there are enough check-in days, the factors are compared with the other days" do
    start = Date.new(2026, 8, 1)
    60.times do |i|
      date = start + i
      bad = i % 3 == 0
      @user.daily_checks.create!(date: date, sleep: bad ? "short" : "good", stress: "low", caffeine: "usual")
      log(date) if bad # pain the same day after every bad night
    end
    visit_stats

    assert_select "[data-factors-summary]", text: /poor night/
    assert_select "tr[data-factor=poor_sleep] td[data-lag='0']", text: /100% vs 0%/
    assert_select "tr[data-factor=high_stress] td[data-lag='0']", text: "–"
  end

  test "moderate-to-severe days are shown under the pain days" do
    log(Date.new(2026, 10, 1)) # intensity 5
    @user.episodes.create!(occurred_on: Date.new(2026, 10, 2), pain_kind: "headache", intensity: 2)
    visit_stats
    assert_equal "1 day at 4/10 or more", figure("severe-days")
  end

  test "each acute drug shows the effects noted and a verdict after 3 rated attacks" do
    %w[none none good].each_with_index do |effect, i|
      log(Date.new(2026, 10, i + 1)).medication_intakes.create!(medication: @acute, effect: effect)
    end
    visit_stats

    assert_select "[data-acute-efficacy] tr[data-medication='Ibuprofen'][data-verdict=not_working]"
    assert_match(/No effect on 2 of the last 3 attacks/, response.body)
  end

  test "no treatment section without any treatment" do
    log(Date.new(2026, 10, 1))
    visit_stats
    assert_select "[data-acute-efficacy]", count: 0
    assert_select "[data-preventives]", count: 0
    assert_select "[data-menstrual]", count: 0
    assert_select "[data-chronic]", count: 0
  end

  test "a preventive is compared with the 90 days before it" do
    propranolol = @user.medications.create!(name: "Propranolol", kind: "preventive")
    start = Date.new(2026, 4, 1)
    (1..9).each { |i| log(start - 9 * i) }
    log(start - 95)
    propranolol.treatment_periods.create!(user: @user, started_on: start)
    [ Date.new(2026, 9, 1), Date.new(2026, 9, 15), Date.new(2026, 10, 1) ].each { |date| log(date) }
    visit_stats

    assert_select "[data-preventives] [data-comparison]", text: /3 days a month before, 1 on the treatment/
    assert_match(/down 67%/, response.body)
  end

  test "the chronic pattern is flagged" do
    (1..15).each { |i| log(Date.new(2026, 10, i), pain: i <= 8 ? "migraine" : "headache") }
    visit_stats
    assert_select "[data-chronic]", text: /Chronic migraine pattern/
  end

  test "the menstrual link only appears with cycle tracking" do
    [ Date.new(2026, 7, 10), Date.new(2026, 8, 7), Date.new(2026, 9, 4) ].each do |start|
      @user.period_days.create!(date: start)
      log(start)
    end
    visit_stats
    assert_select "[data-menstrual]", count: 0

    @user.update!(track_cycle: true)
    visit_stats
    assert_select "[data-menstrual]", text: /3 of the last 3 cycles/
  end

  test "the page is in French under /fr" do
    log(Date.new(2026, 10, 5), medications: [ @triptan ])
    visit_stats(locale: "fr")

    assert_match(/Jours de traitement aigu/, response.body)
    assert_match(/jour de douleur/, response.body)
    assert_match(/C&#39;est un rappel, pas un diagnostic|Sous les limites conseillées/, response.body)
  end

  test "only the user's own data is counted" do
    users(:two).episodes.create!(occurred_on: Date.new(2026, 10, 5), pain_kind: "migraine", intensity: 5)
    log(Date.new(2026, 10, 6))
    visit_stats

    assert_equal "1", figure("pain-days")
  end
end
