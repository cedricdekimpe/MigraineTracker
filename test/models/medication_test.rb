require "test_helper"

class MedicationTest < ActiveSupport::TestCase
  test "names are unique per user ignoring case" do
    assert_not users(:one).medications.new(name: "IBUPROFEN").valid?
    assert users(:two).medications.new(name: "Ibuprofen").valid?
  end

  test "triptan and acute treatment are separate classes" do
    assert_equal %w[acute triptan preventive other], Medication::KINDS
    assert users(:one).medications.new(name: "Zolmitriptan", kind: "triptan").valid?
  end

  test "suggestions are grouped by class and classified ignoring case" do
    assert_includes Medication.suggestions["triptan"], "Sumatriptan"
    assert_includes Medication.suggestions["acute"], "Ibuprofen"
    assert_equal "triptan", Medication.kind_for(" sumatriptan ")
    assert_equal "preventive", Medication.kind_for("Propranolol")
    assert_equal "acute", Medication.kind_for("Something unknown")
  end

  test "kind must be known" do
    assert_not users(:one).medications.new(name: "X", kind: "magic").valid?
    assert users(:one).medications.new(name: "X", kind: "preventive").valid?
  end

  test "abbreviation uses three letters so similar names stay distinct" do
    assert_equal "Ibu", medications(:ibuprofen).abbreviation
    assert_equal "Par", medications(:paracetamol).abbreviation
  end

  test "active and archived scopes" do
    assert_includes users(:one).medications.active, medications(:ibuprofen)
    assert_not_includes users(:one).medications.active, medications(:old_med)
    assert_includes users(:one).medications.archived, medications(:old_med)
  end

  test "retire archives a used medication and keeps the history" do
    medication = medications(:ibuprofen)
    assert_no_difference "MedicationIntake.count" do
      medication.retire!
    end
    assert medication.reload.archived?
  end

  test "retire deletes a medication that was never used" do
    medication = medications(:propranolol)
    assert_difference "Medication.count", -1 do
      medication.retire!
    end
  end

  test "a used medication cannot be destroyed outright" do
    assert_not medications(:ibuprofen).destroy
    assert Medication.exists?(medications(:ibuprofen).id)
  end

  test "find_or_create_for matches ignoring case and un-archives" do
    found = Medication.find_or_create_for(users(:one), "  old med ")
    assert_equal medications(:old_med), found
    assert_not found.reload.archived?
  end

  test "find_or_create_for creates a new one with attributes" do
    assert_difference "Medication.count", 1 do
      created = Medication.find_or_create_for(users(:one), "Sumatriptan", default_dose: "50 mg")
      assert created.persisted?
      assert_equal "50 mg", created.default_dose
    end
  end

  test "most_used_first orders by number of intakes" do
    names = users(:one).medications.active.most_used_first.map(&:name)
    assert_equal "Ibuprofen", names.first
    assert_equal "Paracetamol", names.second
  end
end
