require "test_helper"

class DataImporterTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  def import(data)
    DataImporter.new(@user, data).call
  end

  def migraine_row(overrides = {})
    { "occurred_on" => "2020-01-15", "nature" => "M", "intensity" => 5, "on_period" => false }.merge(overrides)
  end

  test "imports migraines and creates missing medications" do
    result = import("migraines" => [ migraine_row("medication_name" => "Sumatriptan") ])

    assert_equal 1, result.migraines
    assert_equal 1, result.medications
    assert_equal "Sumatriptan", @user.migraines.find_by!(occurred_on: "2020-01-15").medication.name
  end

  test "matches existing medications case-insensitively instead of failing" do
    assert_no_difference "@user.medications.count" do
      result = import("migraines" => [ migraine_row("medication_name" => " ibuprofen ") ])
      assert_equal 1, result.migraines
    end
    assert_equal medications(:one), @user.migraines.find_by!(occurred_on: "2020-01-15").medication
  end

  test "skips dates that already exist, including duplicates inside the file" do
    existing = migraines(:one).occurred_on.iso8601

    result = import("migraines" => [
      migraine_row("occurred_on" => existing),
      migraine_row("occurred_on" => "2020-02-01"),
      migraine_row("occurred_on" => "2020-02-01", "intensity" => 9)
    ])

    assert_equal 1, result.migraines
    assert_equal 5, @user.migraines.find_by!(occurred_on: "2020-02-01").intensity
  end

  test "is all-or-nothing when a later row is invalid" do
    assert_no_difference [ "@user.migraines.count", "@user.medications.count" ] do
      error = assert_raises(DataImporter::InvalidData) do
        import("medications" => [ { "name" => "Brand New" } ],
               "migraines" => [ migraine_row, migraine_row("occurred_on" => "2020-03-01", "intensity" => 99) ])
      end
      assert_match(/Migraine #2/, error.message)
    end
  end

  test "rejects non ISO dates" do
    [ "15/01/2020", "2020-13-45", "Jan 15 2020", "", nil, 20200115, "2020-01-15 and more" ].each do |value|
      error = assert_raises(DataImporter::InvalidData, "expected #{value.inspect} to be rejected") do
        import("migraines" => [ migraine_row("occurred_on" => value) ])
      end
      assert_match(/YYYY-MM-DD/, error.message)
    end
  end

  test "rejects structures that are not a backup" do
    [ nil, [], "string", {}, { "migraines" => "nope" }, { "migraines" => [], "medications" => {} } ].each do |data|
      assert_raises(DataImporter::InvalidData, "expected #{data.inspect} to be rejected") { import(data) }
    end
  end

  test "rejects rows that are not objects" do
    assert_raises(DataImporter::InvalidData) { import("migraines" => [ "2020-01-15" ]) }
    assert_raises(DataImporter::InvalidData) { import("migraines" => [], "medications" => [ "Aspirin" ]) }
    assert_raises(DataImporter::InvalidData) { import("migraines" => [], "medications" => [ { "name" => 42 } ]) }
  end

  test "rejects invalid medication names without leaking exception details" do
    error = assert_raises(DataImporter::InvalidData) do
      import("migraines" => [], "medications" => [ { "name" => "x" * 101 } ])
    end
    assert_no_match(/ActiveRecord|Validation failed/, error.message)
  end

  test "enforces size limits" do
    too_many = Array.new(DataImporter::MAX_MIGRAINES + 1) { migraine_row }
    assert_raises(DataImporter::InvalidData) { import("migraines" => too_many) }

    too_many_meds = Array.new(DataImporter::MAX_MEDICATIONS + 1) { |i| { "name" => "Med #{i}" } }
    assert_raises(DataImporter::InvalidData) { import("migraines" => [], "medications" => too_many_meds) }
  end

  test "treats a missing on_period as false and casts string booleans" do
    import("migraines" => [ migraine_row("on_period" => nil), migraine_row("occurred_on" => "2020-01-16", "on_period" => "true") ])

    assert_equal false, @user.migraines.find_by!(occurred_on: "2020-01-15").on_period
    assert_equal true, @user.migraines.find_by!(occurred_on: "2020-01-16").on_period
  end

  test "never touches another user's data" do
    other = users(:two)
    assert_no_difference "other.migraines.count" do
      import("migraines" => [ migraine_row("medication_name" => medications(:three).name) ])
    end
    assert_not_equal medications(:three).id, @user.migraines.find_by!(occurred_on: "2020-01-15").medication_id
  end
end
