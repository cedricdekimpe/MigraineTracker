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
    log(Date.new(2026, 10, 5), medications: [@triptan])
    log(Date.new(2026, 10, 5)) # same day, still one day
    log(Date.new(2026, 10, 6), pain: "headache", medications: [@acute])
    [Date.new(2026, 7, 1), Date.new(2026, 8, 1), Date.new(2026, 8, 2), Date.new(2026, 9, 1), Date.new(2026, 9, 2), Date.new(2026, 9, 3)].each { |d| log(d) }
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
    assert_select "[data-month-summary].bg-amber-100" # October = first ink of its quarter

    @today = Time.zone.local(2026, 11, 20)
    log(Date.new(2026, 11, 2))
    visit_stats
    assert_select "[data-month-summary].bg-rose-100"
  end

  test "treatment meters stay calm below the thresholds" do
    3.times { |i| log(Date.new(2026, 10, i + 1), medications: [@triptan]) }
    visit_stats

    assert_select "[data-overuse=ok]"
    assert_select "[data-meter=triptan] [role=meter][aria-valuenow='3'][aria-valuemax='10']"
    assert_select "[data-meter=triptan] .bg-accent-500"
    assert_match(/Below the thresholds this month/, response.body)
  end

  test "treatment meters warn near and at the thresholds" do
    8.times { |i| log(Date.new(2026, 10, i + 1), medications: [@triptan]) }
    visit_stats
    assert_select "[data-overuse=watch]"
    assert_select "[data-meter=triptan] .bg-amber-500"
    assert_match(/Getting close to a threshold/, response.body)

    2.times { |i| log(Date.new(2026, 10, i + 9), medications: [@triptan]) }
    visit_stats
    assert_select "[data-overuse=over]"
    assert_select "[data-meter=triptan] .bg-red-500"
    assert_match(/This is a reminder, not a diagnosis/, response.body)
  end

  test "mixing both kinds shows the combined count" do
    5.times { |i| log(Date.new(2026, 10, i + 1), medications: [@triptan]) }
    5.times { |i| log(Date.new(2026, 10, i + 6), medications: [@acute]) }
    visit_stats

    assert_select "[data-overuse=over]"
    assert_match(/Both kinds together: 10 days/, response.body)
  end

  test "twelve months of columns, coloured by month, with the threshold on the treatment chart" do
    log(Date.new(2026, 10, 5), medications: [@acute])
    visit_stats

    assert_select "[data-chart=pain-days] svg[role=img]"
    assert_select "[data-chart=pain-days] svg g rect", count: 1 # only October has a column
    assert_select "[data-chart=pain-days] svg text", text: /oct|Oct/
    assert_select "[data-chart=acute-days] svg line[style*='stroke-dasharray']"
    assert_select "[data-chart=acute-days] svg text", text: "10 days"
    assert_select "[data-chart=pain-days] svg rect[style*='--amber-']" # October's ink
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

  test "triggers are listed with the honest caveat" do
    stress = @user.triggers.find_by!(name: "Stress") # seeded at sign-up
    log(Date.new(2026, 10, 5), triggers: [stress])
    log(Date.new(2026, 10, 6), triggers: [stress])
    log(Date.new(2026, 10, 7))
    visit_stats

    assert_select "[data-triggers] li", text: /Stress.*2 episodes of 3/m
    assert_match(/not what causes it/, response.body)
  end

  test "the page is in French under /fr" do
    log(Date.new(2026, 10, 5), medications: [@triptan])
    visit_stats(locale: "fr")

    assert_match(/Jours de traitement aigu/, response.body)
    assert_match(/jour de douleur/, response.body)
    assert_match(/C&#39;est un rappel, pas un diagnostic|Sous les seuils/, response.body)
  end

  test "only the user's own data is counted" do
    users(:two).episodes.create!(occurred_on: Date.new(2026, 10, 5), pain_kind: "migraine", intensity: 5)
    log(Date.new(2026, 10, 6))
    visit_stats

    assert_equal "1", figure("pain-days")
  end
end
