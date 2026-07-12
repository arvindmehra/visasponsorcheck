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

ActiveRecord::Schema[8.1].define(version: 2026_07_13_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "companies", force: :cascade do |t|
    t.string "company_number"
    t.text "county"
    t.datetime "created_at", null: false
    t.datetime "enriched_at"
    t.string "linkedin_url"
    t.text "name", null: false
    t.text "name_normalised", null: false
    t.text "registered_office_address"
    t.text "slug", null: false
    t.text "town"
    t.text "town_normalised"
    t.datetime "updated_at", null: false
    t.string "website_url"
    t.index ["company_number"], name: "index_companies_on_company_number"
    t.index ["name"], name: "index_companies_on_name"
    t.index ["name_normalised"], name: "index_companies_on_name_normalised", opclass: :gin_trgm_ops, using: :gin
    t.index ["slug"], name: "index_companies_on_slug", unique: true
    t.index ["town"], name: "index_companies_on_town"
    t.index ["town_normalised"], name: "index_companies_on_town_normalised"
  end

  create_table "company_profiles", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "company_status"
    t.string "company_type"
    t.datetime "created_at", null: false
    t.date "date_of_creation"
    t.datetime "enriched_at"
    t.integer "sic_code"
    t.string "sic_code_description"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_company_profiles_on_company_id", unique: true
    t.index ["sic_code"], name: "index_company_profiles_on_sic_code"
  end

  create_table "pghero_query_stats", force: :cascade do |t|
    t.bigint "calls"
    t.datetime "captured_at", precision: nil
    t.text "database"
    t.text "query"
    t.bigint "query_hash"
    t.float "total_time"
    t.text "user"
    t.index ["database", "captured_at"], name: "index_pghero_query_stats_on_database_and_captured_at"
  end

  create_table "search_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "query", null: false
    t.integer "results_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["query"], name: "index_search_logs_on_query"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
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
    t.index ["licence_type"], name: "index_sponsor_licences_on_licence_type"
    t.index ["rating"], name: "index_sponsor_licences_on_rating"
    t.index ["route", "status"], name: "index_sponsor_licences_on_route_and_status"
    t.index ["route"], name: "index_sponsor_licences_on_route"
    t.index ["status"], name: "index_sponsor_licences_on_status"
  end

  add_foreign_key "company_profiles", "companies"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "sponsor_change_events", "companies"
  add_foreign_key "sponsor_change_events", "sponsor_import_logs"
  add_foreign_key "sponsor_licences", "companies"
end
