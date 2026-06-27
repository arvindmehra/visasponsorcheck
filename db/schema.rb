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

ActiveRecord::Schema[8.1].define(version: 2026_06_27_003949) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "companies", force: :cascade do |t|
    t.text "county"
    t.datetime "created_at", null: false
    t.text "name", null: false
    t.text "name_normalised", null: false
    t.text "slug", null: false
    t.text "town"
    t.datetime "updated_at", null: false
    t.index ["name_normalised"], name: "index_companies_on_name_normalised", opclass: :gin_trgm_ops, using: :gin
    t.index ["slug"], name: "index_companies_on_slug", unique: true
  end

  create_table "sponsor_change_events", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.text "event_type", null: false
    t.text "field_name"
    t.text "new_value"
    t.datetime "occurred_at", null: false
    t.text "old_value"
    t.bigint "sponsor_import_log_id", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_sponsor_change_events_on_company_id"
    t.index ["sponsor_import_log_id"], name: "index_sponsor_change_events_on_sponsor_import_log_id"
  end

  create_table "sponsor_import_logs", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "csv_filename"
    t.text "error_message"
    t.integer "new_licences", default: 0, null: false
    t.integer "removed_licences", default: 0, null: false
    t.text "source_url", null: false
    t.datetime "started_at"
    t.text "status", default: "pending", null: false
    t.integer "total_rows", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "updated_licences", default: 0, null: false
  end

  create_table "sponsor_licences", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "first_seen_at", null: false
    t.datetime "last_seen_at", null: false
    t.text "licence_type", null: false
    t.text "organisation_name", null: false
    t.text "rating", null: false
    t.text "route", null: false
    t.text "status", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "route"], name: "index_sponsor_licences_on_company_id_and_route", unique: true
    t.index ["company_id"], name: "index_sponsor_licences_on_company_id"
  end

  add_foreign_key "sponsor_change_events", "companies"
  add_foreign_key "sponsor_change_events", "sponsor_import_logs"
  add_foreign_key "sponsor_licences", "companies"
end
