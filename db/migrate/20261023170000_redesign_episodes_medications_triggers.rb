# Replaces the one-migraine-per-day model (nature codes M/H/A/MA/MH, single medication)
# with episodes (several per day, aura independent from pain), medication intakes and triggers.
# Production held no real data when this was written, so the old table is dropped, not migrated.
class RedesignEpisodesMedicationsTriggers < ActiveRecord::Migration[8.1]
  def change
    drop_table :migraines do |t|
      t.integer :user_id, null: false
      t.integer :medication_id
      t.date :occurred_on, null: false
      t.string :nature, null: false
      t.integer :intensity, null: false
      t.boolean :on_period, null: false, default: false
      t.timestamps
    end

    change_table :users do |t|
      t.boolean :track_cycle, null: false, default: false
    end

    change_table :medications do |t|
      t.string :kind, null: false, default: "acute"
      t.string :default_dose
      t.datetime :archived_at
    end
    add_index :medications, [:user_id, :archived_at]

    create_table :episodes do |t|
      t.references :user, null: false, foreign_key: true
      t.date :occurred_on, null: false
      t.time :started_time
      t.integer :duration_minutes
      t.boolean :aura, null: false, default: false
      t.string :pain_kind
      t.integer :intensity
      t.boolean :on_period, null: false, default: false
      t.text :notes
      t.timestamps

      t.check_constraint "aura = 1 OR pain_kind IS NOT NULL", name: "episodes_aura_or_pain"
      t.check_constraint "intensity IS NULL OR (intensity >= 1 AND intensity <= 10)", name: "episodes_intensity_range"
      t.index [:user_id, :occurred_on]
    end

    create_table :medication_intakes do |t|
      t.references :episode, null: false, foreign_key: true
      t.references :medication, null: false, foreign_key: true
      t.string :dose
      t.time :taken_time
      t.string :effect
      t.timestamps
    end

    create_table :triggers do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps

      t.index "user_id, lower(name)", unique: true, name: "index_triggers_on_user_id_and_lower_name"
    end

    create_table :episode_triggers do |t|
      t.references :episode, null: false, foreign_key: true
      t.references :trigger, null: false, foreign_key: true
      t.timestamps

      t.index [:episode_id, :trigger_id], unique: true
    end
  end
end
