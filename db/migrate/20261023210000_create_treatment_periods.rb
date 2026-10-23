# A preventive treatment is taken for months, not per attack: it is recorded as dated periods so that
# its effect can be judged (3 months at target dose) and so that the failed attempts a neurologist or
# the health insurance asks about are on record.
class CreateTreatmentPeriods < ActiveRecord::Migration[8.1]
  def change
    create_table :treatment_periods do |t|
      t.references :user, null: false, foreign_key: true
      t.references :medication, null: false, foreign_key: true
      t.date :started_on, null: false
      t.date :ended_on
      t.string :dose
      t.string :stop_reason
      t.timestamps
    end
    add_check_constraint :treatment_periods, "ended_on IS NULL OR ended_on >= started_on", name: "treatment_periods_dates_in_order"
  end
end
