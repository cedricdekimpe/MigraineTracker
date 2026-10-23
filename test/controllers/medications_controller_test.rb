require "test_helper"

class MedicationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
  end

  test "account page lists active medications, archived ones and suggestions" do
    get account_medications_path

    assert_response :success
    assert_select "input[value='Ibuprofen']"
    assert_select "input[value='Old Med']", count: 0
    assert_select "li", text: /Old Med/
    assert_select "form[action='#{unarchive_medication_path(id: medications(:old_med))}']"
    assert_select "button", text: "Sumatriptan"
    assert_select "button", text: "Ibuprofen", count: 0
  end

  test "each medication is a compact row whose edit form is folded, open after its own update" do
    get account_medications_path
    assert_select "li[data-medication-row] details[data-medication-edit]:not([open]) form", minimum: 1
    assert_select "details[data-suggestions]:not([open])"

    get account_medications_path(open: medications(:ibuprofen).id)
    assert_select "li#medication-#{medications(:ibuprofen).id} details[data-medication-edit][open]"
  end

  test "create adds a medication with kind and dose" do
    assert_difference "@user.medications.count", 1 do
      post medications_path, params: { medication: { name: "Sumatriptan", kind: "acute", default_dose: "50 mg" } }
    end

    assert_redirected_to account_medications_path
    assert_equal "50 mg", @user.medications.find_by!(name: "Sumatriptan").default_dose
  end

  test "create rejects a duplicate name ignoring case" do
    assert_no_difference "Medication.count" do
      post medications_path, params: { medication: { name: "ibuprofen" } }
    end
    assert_redirected_to account_medications_path
    assert flash[:alert].present?
  end

  test "update renames and changes kind" do
    patch medication_path(id: medications(:paracetamol)), params: { medication: { name: "Acetaminophen", kind: "other", default_dose: "1 g" } }

    medication = medications(:paracetamol).reload
    assert_equal ["Acetaminophen", "other", "1 g"], [medication.name, medication.kind, medication.default_dose]
  end

  test "removing a used medication archives it and keeps the history" do
    assert_no_difference "MedicationIntake.count" do
      delete medication_path(id: medications(:ibuprofen))
    end

    assert medications(:ibuprofen).reload.archived?
    assert_equal I18n.t("flash.medication_archived"), flash[:notice]
  end

  test "removing an unused medication deletes it" do
    assert_difference "Medication.count", -1 do
      delete medication_path(id: medications(:propranolol))
    end
    assert_equal I18n.t("flash.medication_deleted"), flash[:notice]
  end

  test "restore brings an archived medication back" do
    patch unarchive_medication_path(id: medications(:old_med))
    assert_not medications(:old_med).reload.archived?
  end

  test "cannot touch another user's medication" do
    delete medication_path(id: medications(:aspirin))
    assert_response :not_found

    sign_in @user
    patch medication_path(id: medications(:aspirin)), params: { medication: { name: "Hacked" } }
    assert_response :not_found
    assert_equal "Aspirin", medications(:aspirin).reload.name
  end
end
