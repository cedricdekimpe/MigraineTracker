class AddMedicationToMigraines < ActiveRecord::Migration[8.1]
  class MigrationMedication < ApplicationRecord
    self.table_name = "medications"
    belongs_to :user, class_name: "AddMedicationToMigraines::MigrationUser", foreign_key: :user_id
  end

  class MigrationMigraine < ApplicationRecord
    self.table_name = "migraines"
    belongs_to :user, class_name: "AddMedicationToMigraines::MigrationUser", foreign_key: :user_id
    belongs_to :medication, class_name: "AddMedicationToMigraines::MigrationMedication", optional: true
  end

  class MigrationUser < ApplicationRecord
    self.table_name = "users"
    has_many :medications, class_name: "AddMedicationToMigraines::MigrationMedication", foreign_key: :user_id
  end

  def up
    unless column_exists?(:migraines, :medication_id)
      add_reference :migraines, :medication, foreign_key: true
    end

    MigrationMigraine.reset_column_information
    MigrationMedication.reset_column_information

    migrate_existing_medications

    remove_column :migraines, :medication, :string
  end

  def down
    add_column :migraines, :medication, :string unless column_exists?(:migraines, :medication)

    MigrationMigraine.reset_column_information
    MigrationMedication.reset_column_information

    MigrationMigraine.includes(:medication).find_each do |migraine|
      migraine.update_columns(medication: migraine.medication&.name)
    end

    remove_reference :migraines, :medication, foreign_key: true if column_exists?(:migraines, :medication_id)
  end

  private

  def migrate_existing_medications
    MigrationUser.find_each do |user|
      ensure_default_medications(user)
    end

    MigrationMigraine.where.not(medication: [ nil, "" ]).find_each do |migraine|
      name = migraine.medication.to_s.strip
      next if name.blank?

      medication = MigrationMedication.find_or_create_by!(user_id: migraine.user_id, name: name)
      migraine.update_columns(medication_id: medication.id)
    end
  end

  def ensure_default_medications(user)
    %w[Ibuprofen Triptan].each do |name|
      user.medications.find_or_create_by!(name: name)
    rescue ActiveRecord::RecordInvalid
      next
    end
  end
end
