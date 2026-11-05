# The mobile app creates records offline: each one carries an identifier made on the phone, so that sending
# it twice does not create it twice. Rows made on the web get one from the database.
class AddUuidToSyncedRecords < ActiveRecord::Migration[8.1]
  TABLES = %i[episodes medication_intakes period_days daily_checks].freeze
  RANDOM_ID = -> { "(lower(hex(randomblob(16))))" }

  def up
    TABLES.each do |table|
      add_column table, :uuid, :string
      execute "UPDATE #{table} SET uuid = lower(hex(randomblob(16)))"
      change_column_default table, :uuid, RANDOM_ID
      change_column_null table, :uuid, false
      add_index table, :uuid, unique: true
    end
  end

  def down
    TABLES.each { |table| remove_column table, :uuid }
  end
end
