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

ActiveRecord::Schema[8.1].define(version: 2025_12_19_090000) do
  create_table "medications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "name"], name: "index_medications_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_medications_on_user_id"
  end

  create_table "migraines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "intensity", null: false
    t.integer "medication_id"
    t.string "nature", null: false
    t.date "occurred_on", null: false
    t.boolean "on_period", default: false, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["medication_id"], name: "index_migraines_on_medication_id"
    t.index ["user_id", "occurred_on"], name: "index_migraines_on_user_id_and_occurred_on", unique: true
    t.index ["user_id"], name: "index_migraines_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["admin"], name: "index_users_on_admin"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "medications", "users"
  add_foreign_key "migraines", "medications"
  add_foreign_key "migraines", "users"
end
