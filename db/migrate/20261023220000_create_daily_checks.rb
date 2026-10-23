# The daily check-in: three factors noted every day, with or without an attack. Without the days that
# went well there is nothing to compare the bad days with, which is why tags on attacks alone say
# nothing about triggers.
class CreateDailyChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_checks do |t|
      t.references :user, null: false, foreign_key: true
      t.date :date, null: false
      t.string :sleep
      t.string :stress
      t.boolean :skipped_meal, null: false, default: false
      t.string :caffeine
      t.timestamps
    end
    add_index :daily_checks, %i[user_id date], unique: true
  end
end
