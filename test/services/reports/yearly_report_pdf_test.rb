require "test_helper"

class Reports::YearlyReportPdfTest < ActiveSupport::TestCase
  setup do
    @user = User.create!({ email: "report@example.com", password: "password123" }.merge(consent_attrs))
    @triptan = @user.medications.create!(name: "Sumatriptan", kind: "triptan")
    @acute = @user.medications.create!(name: "Ibuprofen", kind: "acute")
  end

  def episode(date, pain: "migraine", aura: false, intensity: 7, medications: [])
    record = @user.episodes.create!(occurred_on: date, pain_kind: pain, aura: aura, intensity: pain ? intensity : nil)
    medications.each { |medication| record.medication_intakes.create!(medication: medication) }
    record
  end

  def reader(year: 2025, today: Date.new(2026, 1, 15), locale: :en)
    pdf = I18n.with_locale(locale) { Reports::YearlyReportPdf.new(user: @user, year: year, today: today).render }
    PDF::Reader.new(StringIO.new(pdf))
  end

  def text(reader, page)
    reader.pages[page - 1].text
  end

  # Page number of the first quarter sheet: after the summary and, when there is anything to say, the indicators page
  def first_sheet(reader)
    reader.pages.index { |page| page.text =~ /Month:|Mois :/ } + 1
  end

  # Same text with every run of whitespace collapsed: narrow cells wrap their labels over lines.
  def flat(reader, page)
    text(reader, page).gsub(/\s+/, " ")
  end

  test "a summary page followed by the four quarter sheets for a past year" do
    pdf = reader
    assert_equal 5, pdf.page_count
    assert_match(/Migraine calendar - 2025/, text(pdf, 1))
    assert_match(/Summary/, text(pdf, 1))
  end

  test "the running year only prints the quarters that have started" do
    assert_equal 3, reader(year: 2026, today: Date.new(2026, 5, 10)).page_count # summary + Q1 + Q2
    assert_equal 2, reader(year: 2026, today: Date.new(2026, 2, 1)).page_count # summary + Q1
  end

  test "the summary counts days with pain, migraine days and treatment days by class" do
    episode(Date.new(2025, 3, 3), medications: [@triptan])
    episode(Date.new(2025, 3, 3)) # same day
    episode(Date.new(2025, 3, 4), pain: "headache", intensity: 3, medications: [@acute])
    episode(Date.new(2025, 3, 5), pain: nil, aura: true)
    summary = text(reader, 1)

    march = summary.lines.find { |line| line.include?("March") }
    assert_equal %w[2 1 1 1 1 1 2], march.scan(/\b\d+\b/), march
  end

  test "overuse is flagged on the month that reaches a threshold" do
    10.times { |i| episode(Date.new(2025, 5, i + 1), medications: [@triptan]) }
    summary = text(reader, 1)

    assert_match(/May.*Threshold reached/, summary)
    assert_match(/January.*Below the limits/, summary)
    assert_match(/Status counts, per month/, summary)
  end

  test "future months are left blank in the summary and the average only covers months so far" do
    episode(Date.new(2026, 1, 5))
    episode(Date.new(2026, 1, 6))
    summary = text(reader(year: 2026, today: Date.new(2026, 1, 20)), 1)

    assert_match(/Average \(months so far\) 2\b/, summary.gsub(/\s+/, " "))
    assert_no_match(/February.*Below the limits/, summary)
  end

  test "the sheet pages reproduce the paper: month frames, letters, intensity and treatment marks" do
    episode(Date.new(2025, 1, 10), aura: true, intensity: 9, medications: [@acute, @triptan])
    episode(Date.new(2025, 1, 11), pain: "headache", intensity: 4)
    episode(Date.new(2025, 1, 12), pain: nil, aura: true)
    pdf = reader
    sheet = flat(pdf, first_sheet(pdf))

    %w[January February March].each { |month| assert_match(/Month: #{month} 2025/, sheet) }
    assert_match(/Migraine \(M\) \/ Headache \(T\)/, sheet)
    assert_match(/Pain intensity/, sheet)
    assert_match(/Acute treatment/, sheet)
    assert_match(/Ma/, sheet) # migraine with aura
    assert_match(/\bT\b/, sheet)
    assert_match(/\bA\b/, sheet)
    assert_match(/\b9\b/, sheet)
    assert_match(/X t/, sheet) # acute and triptan the same day
    assert_match(/Legend/, sheet)
  end

  test "the cycle row only appears when cycle tracking is on" do
    episode(Date.new(2025, 1, 10))
    @user.period_days.create!(date: Date.new(2025, 1, 10))
    pdf = reader
    assert_no_match(/Menstrual cycle/, text(pdf, first_sheet(pdf)))

    @user.update!(track_cycle: true)
    pdf = reader
    assert_match(/Menstrual cycle/, text(pdf, first_sheet(pdf)))
  end

  test "no indicators page when there is nothing to show" do
    episode(Date.new(2025, 1, 10))
    assert_equal 5, reader.page_count
    assert_no_match(/Indicators/, text(reader, 2))
  end

  test "an indicators page follows the summary with the effect of each acute drug" do
    episode(Date.new(2025, 1, 10), medications: [@acute]).medication_intakes.first.update!(effect: "none")
    pdf = reader
    assert_equal 6, pdf.page_count
    page = flat(pdf, 2)
    assert_match(/Indicators - 2025/, page)
    assert_match(/Acute treatments/, page)
    assert_match(/Ibuprofen 1 1 0 0/, page)
    assert_match(/Fewer than 3 attacks rated/, page)
    assert_match(/Pain days at 4\/10 or more: 1/, page)
  end

  test "the indicators page lists preventive periods and the menstrual link" do
    propranolol = @user.medications.create!(name: "Propranolol", kind: "preventive")
    propranolol.treatment_periods.create!(user: @user, started_on: Date.new(2025, 2, 1), ended_on: Date.new(2025, 3, 20), stop_reason: "not_tolerated", dose: "80 mg")
    @user.update!(track_cycle: true)
    [Date.new(2025, 1, 5), Date.new(2025, 2, 2), Date.new(2025, 3, 1)].each { |start| @user.period_days.create!(date: start); episode(start) }
    page = flat(reader, 2)

    assert_match(/Preventive treatments/, page)
    assert_match(/Propranolol/, page)
    assert_match(/Not well tolerated/, page)
    assert_match(/3 of the last 3 cycles/, page)
  end

  test "a chronic pattern is stated on the indicators page" do
    (1..15).each { |day| episode(Date.new(2025, 12, day), pain: day <= 8 ? "migraine" : "headache") }
    assert_match(/chronic migraine pattern/, flat(reader(today: Date.new(2025, 12, 31)), 2))
  end

  test "the report speaks French with decimal commas" do
    [Date.new(2025, 2, 1), Date.new(2025, 2, 2), Date.new(2025, 3, 1)].each { |date| episode(date) }
    pdf = reader(locale: :fr)

    assert_match(/Calendrier des migraines - 2025/, text(pdf, 1))
    assert_match(/Moyenne \(mois écoulés\)/, flat(pdf, 1))
    assert_match(/Mois : janvier 2025/, text(pdf, 2))
    assert_match(/Outil de suivi personnel/, text(pdf, 1))
    assert_match(/\b0,3\b/, text(pdf, 1)) # 3 pain days over 12 months
  end

  test "an empty year still renders" do
    assert_equal 5, reader.page_count
  end

  test "other users' data never appears" do
    users(:two).episodes.create!(occurred_on: Date.new(2025, 3, 3), pain_kind: "migraine", intensity: 5)
    march = text(reader, 1).lines.find { |line| line.include?("March") }

    assert_equal %w[0 0 0 0 0 0 0], march.scan(/\b\d+\b/)
  end
end
