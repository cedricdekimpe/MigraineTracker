require "test_helper"

class DataImporterTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  def import(data)
    DataImporter.new(@user, data).call
  end

  def episode_row(overrides = {})
    { "occurred_on" => "2020-01-15", "pain_kind" => "migraine", "intensity" => 5 }.merge(overrides)
  end

  test "imports episodes and creates missing medications and triggers" do
    result = import("episodes" => [episode_row("medications" => [{ "name" => "Sumatriptan", "dose" => "50 mg" }], "triggers" => ["Noise"])])

    assert_equal [1, 1, 1], [result.episodes, result.medications, result.triggers]
    episode = @user.episodes.find_by!(occurred_on: "2020-01-15")
    assert_equal "50 mg", episode.medication_intakes.first.dose
    assert_equal ["Noise"], episode.triggers.map(&:name)
  end

  test "matches existing medications and triggers ignoring case" do
    assert_no_difference ["@user.medications.count", "@user.triggers.count"] do
      import("episodes" => [episode_row("medications" => [{ "name" => " ibuprofen " }], "triggers" => ["STRESS"])])
    end
  end

  test "reuses archived medications without un-archiving them" do
    import("episodes" => [episode_row("medications" => [{ "name" => "Old Med" }])])
    assert medications(:old_med).reload.archived?
  end

  test "creates archived medications from the backup and honours their kind" do
    import("medications" => [{ "name" => "Retired", "kind" => "preventive", "default_dose" => "20 mg", "archived" => true }], "episodes" => [])

    medication = @user.medications.find_by!(name: "Retired")
    assert_equal ["preventive", "20 mg", true], [medication.kind, medication.default_dose, medication.archived?]
  end

  test "ignores an unknown medication kind instead of failing" do
    import("medications" => [{ "name" => "Odd", "kind" => "magic" }], "episodes" => [])
    assert_equal "acute", @user.medications.find_by!(name: "Odd").kind
  end

  test "keeps several episodes on the same day but skips exact duplicates" do
    existing = episodes(:headache)
    duplicate = episode_row("occurred_on" => existing.occurred_on.iso8601, "pain_kind" => "headache", "intensity" => 4)

    result = import("episodes" => [duplicate, duplicate.merge("intensity" => 6), episode_row, episode_row("started_time" => "09:00")])

    assert_equal 3, result.episodes
  end

  test "is all-or-nothing when a later row is invalid" do
    assert_no_difference ["@user.episodes.count", "@user.medications.count", "@user.triggers.count"] do
      error = assert_raises(DataImporter::InvalidData) do
        import("medications" => [{ "name" => "Brand New" }], "triggers" => ["Fresh"],
               "episodes" => [episode_row, episode_row("occurred_on" => "2020-03-01", "intensity" => 99)])
      end
      assert_match(/Episode #2/, error.message)
    end
  end

  test "enforces the aura-or-pain rule per episode" do
    error = assert_raises(DataImporter::InvalidData) { import("episodes" => [{ "occurred_on" => "2020-01-01" }]) }
    assert_match(/Episode #1/, error.message)

    assert_nothing_raised { import("episodes" => [{ "occurred_on" => "2020-01-02", "aura" => true }]) }
  end

  test "rejects non ISO dates" do
    ["15/01/2020", "2020-13-45", "Jan 15 2020", "", nil, 20200115, "2020-01-15 and more"].each do |value|
      error = assert_raises(DataImporter::InvalidData, "expected #{value.inspect} to be rejected") do
        import("episodes" => [episode_row("occurred_on" => value)])
      end
      assert_match(/YYYY-MM-DD/, error.message)
    end
  end

  test "rejects invalid times" do
    ["25:00", "9:5", "noon", 900].each do |value|
      assert_raises(DataImporter::InvalidData, "expected #{value.inspect} to be rejected") do
        import("episodes" => [episode_row("started_time" => value)])
      end
    end
    assert_raises(DataImporter::InvalidData) do
      import("episodes" => [episode_row("medications" => [{ "name" => "Ibuprofen", "taken_time" => "99:99" }])])
    end
  end

  test "rejects structures that are not a backup" do
    [nil, [], "string", {}, { "episodes" => "nope" }, { "episodes" => [], "medications" => {} }, { "episodes" => [], "triggers" => "x" }].each do |data|
      assert_raises(DataImporter::InvalidData, "expected #{data.inspect} to be rejected") { import(data) }
    end
  end

  test "rejects rows that are not objects or have bad names" do
    assert_raises(DataImporter::InvalidData) { import("episodes" => ["2020-01-15"]) }
    assert_raises(DataImporter::InvalidData) { import("episodes" => [], "medications" => ["Aspirin"]) }
    assert_raises(DataImporter::InvalidData) { import("episodes" => [], "medications" => [{ "name" => 42 }]) }
    assert_raises(DataImporter::InvalidData) { import("episodes" => [], "triggers" => [42]) }
  end

  test "rejects invalid names without leaking exception details" do
    error = assert_raises(DataImporter::InvalidData) { import("episodes" => [], "medications" => [{ "name" => "x" * 101 }]) }
    assert_no_match(/ActiveRecord|Validation failed/, error.message)
  end

  test "enforces size limits" do
    assert_raises(DataImporter::InvalidData) { import("episodes" => Array.new(DataImporter::MAX_EPISODES + 1) { episode_row }) }
    assert_raises(DataImporter::InvalidData) { import("episodes" => [], "medications" => Array.new(DataImporter::MAX_MEDICATIONS + 1) { |i| { "name" => "Med #{i}" } }) }
    assert_raises(DataImporter::InvalidData) { import("episodes" => [], "triggers" => Array.new(DataImporter::MAX_TRIGGERS + 1) { |i| { "name" => "Trigger #{i}" } }) }
  end

  test "casts string booleans and treats missing flags as false" do
    import("episodes" => [episode_row("on_period" => "true", "aura" => nil)])

    episode = @user.episodes.find_by!(occurred_on: "2020-01-15")
    assert_equal [true, false], [episode.on_period, episode.aura]
  end

  test "never touches another user's data" do
    assert_no_difference "users(:two).medications.count" do
      import("episodes" => [episode_row("medications" => [{ "name" => medications(:aspirin).name }])])
    end
    assert_not_equal medications(:aspirin).id, @user.episodes.find_by!(occurred_on: "2020-01-15").medications.first.id
  end
end
