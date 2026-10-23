# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_23_180000) do
  create_table "episode_triggers", force: :cascade do |t|
    t.integer "episode_id", null: false
    t.integer "trigger_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["episode_id", "trigger_id"], name: "index_episode_triggers_on_episode_id_and_trigger_id", unique: true
    t.index ["episode_id"], name: "index_episode_triggers_on_episode_id"
    t.index ["trigger_id"], name: "index_episode_triggers_on_trigger_id"
  end

  create_table "episodes", force: :cascade do |t|
    t.integer "user_id", null: false
    t.date "occurred_on", null: false
    t.time "started_time"
    t.integer "duration_minutes"
    t.boolean "aura", default: false, null: false
    t.string "pain_kind"
    t.integer "intensity"
    t.boolean "on_period", default: false, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "occurred_on"], name: "index_episodes_on_user_id_and_occurred_on"
    t.index ["user_id"], name: "index_episodes_on_user_id"
    t.check_constraint "aura = 1 OR pain_kind IS NOT NULL", name: "episodes_aura_or_pain"
    t.check_constraint "intensity IS NULL OR (intensity >= 1 AND intensity <= 10)", name: "episodes_intensity_range"
  end

  create_table "medication_intakes", force: :cascade do |t|
    t.integer "episode_id", null: false
    t.integer "medication_id", null: false
    t.string "dose"
    t.time "taken_time"
    t.string "effect"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["episode_id"], name: "index_medication_intakes_on_episode_id"
    t.index ["medication_id"], name: "index_medication_intakes_on_medication_id"
  end

  create_table "medications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "kind", default: "acute", null: false
    t.string "default_dose"
    t.datetime "archived_at"
    t.index ["user_id", "archived_at"], name: "index_medications_on_user_id_and_archived_at"
    t.index ["user_id", "name"], name: "index_medications_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_medications_on_user_id"
  end

  create_table "triggers", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "user_id, lower(name)", name: "index_triggers_on_user_id_and_lower_name", unique: true
    t.index ["user_id"], name: "index_triggers_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "health_data_consent_given_at"
    t.text "health_data_consent_text"
    t.string "health_data_consent_version"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.boolean "track_cycle", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["health_data_consent_version"], name: "index_users_on_health_data_consent_version"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "episode_triggers", "episodes"
  add_foreign_key "episode_triggers", "triggers"
  add_foreign_key "episodes", "users"
  add_foreign_key "medication_intakes", "episodes"
  add_foreign_key "medication_intakes", "medications"
  add_foreign_key "medications", "users"
  add_foreign_key "triggers", "users"
end
