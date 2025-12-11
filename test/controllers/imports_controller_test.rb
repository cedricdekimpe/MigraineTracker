require "test_helper"

class ImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "should require authentication for new" do
    sign_out @user
    get new_import_path
    assert_redirected_to new_user_session_path
  end

  test "should require authentication for create" do
    sign_out @user
    post imports_path
    assert_redirected_to new_user_session_path
  end

  test "should get new import page" do
    get new_import_path
    assert_response :success
    assert_select "h1", "Import Data"
  end

  test "should show file upload form" do
    get new_import_path
    assert_response :success
    assert_select "input[type='file'][name='file']"
  end

  test "should reject import without file" do
    post imports_path
    assert_redirected_to new_import_path
    assert_equal "Please select a file to import.", flash[:alert]
  end

  test "should reject invalid JSON file" do
    file = fixture_file_upload("files/invalid.json", "application/json")
    post imports_path, params: { file: file }
    
    assert_redirected_to new_import_path
    assert_match /Invalid JSON file/, flash[:alert]
  end

  test "should reject JSON with wrong user email" do
    export_data = {
      exported_at: Time.current.iso8601,
      user_email: "wrong@example.com",
      medications: [],
      migraines: []
    }
    
    file = Rack::Test::UploadedFile.new(
      StringIO.new(export_data.to_json),
      "application/json",
      original_filename: "export.json"
    )
    
    post imports_path, params: { file: file }
    assert_redirected_to new_import_path
    assert_match /does not match your account/, flash[:alert]
  end

  test "should successfully import medications" do
    export_data = {
      exported_at: Time.current.iso8601,
      user_email: @user.email,
      medications: [
        { name: "Aspirin", created_at: 1.day.ago.iso8601 },
        { name: "Ibuprofen", created_at: 2.days.ago.iso8601 }
      ],
      migraines: []
    }
    
    file = Rack::Test::UploadedFile.new(
      StringIO.new(export_data.to_json),
      "application/json",
      original_filename: "export.json"
    )
    
    assert_difference "@user.medications.count", 2 do
      post imports_path, params: { file: file }
    end
    
    assert_redirected_to edit_user_registration_path
    assert_equal "Successfully imported 2 medications and 0 migraines.", flash[:notice]
    
    assert @user.medications.exists?(name: "Aspirin")
    assert @user.medications.exists?(name: "Ibuprofen")
  end

  test "should successfully import migraines with medications" do
    # First create a medication
    medication = @user.medications.create!(name: "Test Med")
    
    export_data = {
      exported_at: Time.current.iso8601,
      user_email: @user.email,
      medications: [
        { name: "Test Med", created_at: 1.day.ago.iso8601 }
      ],
      migraines: [
        {
          occurred_on: Date.today.to_s,
          nature: "strong",
          intensity: 8,
          on_period: false,
          medication_name: "Test Med",
          created_at: Time.current.iso8601
        }
      ]
    }
    
    file = Rack::Test::UploadedFile.new(
      StringIO.new(export_data.to_json),
      "application/json",
      original_filename: "export.json"
    )
    
    initial_count = @user.migraines.count
    post imports_path, params: { file: file }
    
    assert_redirected_to edit_user_registration_path
    assert_equal "Successfully imported 0 medications and 1 migraines.", flash[:notice]
    
    migraine = @user.migraines.last
    assert_equal Date.today, migraine.occurred_on
    assert_equal "strong", migraine.nature
    assert_equal 8, migraine.intensity
    assert_equal false, migraine.on_period
    assert_equal medication.id, migraine.medication_id
  end

  test "should skip duplicate migraines based on occurred_on date" do
    # Create existing migraine
    @user.migraines.create!(
      occurred_on: Date.today,
      nature: "weak",
      intensity: 3,
      on_period: false
    )
    
    export_data = {
      exported_at: Time.current.iso8601,
      user_email: @user.email,
      medications: [],
      migraines: [
        {
          occurred_on: Date.today.to_s,
          nature: "strong",
          intensity: 8,
          on_period: true,
          medication_name: nil,
          created_at: Time.current.iso8601
        }
      ]
    }
    
    file = Rack::Test::UploadedFile.new(
      StringIO.new(export_data.to_json),
      "application/json",
      original_filename: "export.json"
    )
    
    assert_no_difference "@user.migraines.count" do
      post imports_path, params: { file: file }
    end
    
    # Verify original migraine data wasn't changed
    migraine = @user.migraines.find_by(occurred_on: Date.today)
    assert_equal "weak", migraine.nature
    assert_equal 3, migraine.intensity
  end

  test "should handle migraines without medication" do
    export_data = {
      exported_at: Time.current.iso8601,
      user_email: @user.email,
      medications: [],
      migraines: [
        {
          occurred_on: Date.today.to_s,
          nature: "weak",
          intensity: 4,
          on_period: true,
          medication_name: nil,
          created_at: Time.current.iso8601
        }
      ]
    }
    
    file = Rack::Test::UploadedFile.new(
      StringIO.new(export_data.to_json),
      "application/json",
      original_filename: "export.json"
    )
    
    assert_difference "@user.migraines.count", 1 do
      post imports_path, params: { file: file }
    end
    
    migraine = @user.migraines.last
    assert_nil migraine.medication_id
  end

  test "should rollback on error during import" do
    # Create invalid data that will cause an error
    export_data = {
      exported_at: Time.current.iso8601,
      user_email: @user.email,
      medications: [],
      migraines: [
        {
          occurred_on: "invalid-date",
          nature: "strong",
          intensity: 8,
          on_period: false,
          medication_name: nil,
          created_at: Time.current.iso8601
        }
      ]
    }
    
    file = Rack::Test::UploadedFile.new(
      StringIO.new(export_data.to_json),
      "application/json",
      original_filename: "export.json"
    )
    
    assert_no_difference "@user.migraines.count" do
      post imports_path, params: { file: file }
    end
    
    assert_redirected_to new_import_path
    assert_match /Error importing data/, flash[:alert]
  end

  test "should create medication if it doesn't exist when importing migraine" do
    export_data = {
      exported_at: Time.current.iso8601,
      user_email: @user.email,
      medications: [
        { name: "New Med", created_at: 1.day.ago.iso8601 }
      ],
      migraines: [
        {
          occurred_on: Date.today.to_s,
          nature: "strong",
          intensity: 7,
          on_period: false,
          medication_name: "New Med",
          created_at: Time.current.iso8601
        }
      ]
    }
    
    file = Rack::Test::UploadedFile.new(
      StringIO.new(export_data.to_json),
      "application/json",
      original_filename: "export.json"
    )
    
    assert_difference "@user.medications.count", 1 do
      post imports_path, params: { file: file }
    end
    
    medication = @user.medications.find_by(name: "New Med")
    assert_not_nil medication
    
    migraine = @user.migraines.last
    assert_equal medication.id, migraine.medication_id
  end
end
