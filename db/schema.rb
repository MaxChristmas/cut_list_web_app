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

ActiveRecord::Schema[8.1].define(version: 2026_03_17_150003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
  end

  create_table "coupon_redemptions", force: :cascade do |t|
    t.bigint "coupon_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["coupon_id", "user_id"], name: "index_coupon_redemptions_on_coupon_id_and_user_id", unique: true
    t.index ["coupon_id"], name: "index_coupon_redemptions_on_coupon_id"
    t.index ["user_id"], name: "index_coupon_redemptions_on_user_id"
  end

  create_table "coupons", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.integer "duration_days", null: false
    t.datetime "expires_at"
    t.integer "max_uses"
    t.string "plan", null: false
    t.datetime "updated_at", null: false
    t.integer "uses_count", default: 0, null: false
    t.index ["code"], name: "index_coupons_on_code", unique: true
  end

  create_table "optimizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "cut_direction", default: "auto", null: false
    t.jsonb "edited_result"
    t.decimal "efficiency"
    t.bigint "project_id", null: false
    t.jsonb "result"
    t.bigint "scan_token_id"
    t.integer "sheets_count"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_optimizations_on_project_id"
    t.index ["scan_token_id"], name: "index_optimizations_on_scan_token_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "archived_at"
    t.integer "bonus_optimizations", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "grain_direction", default: "none", null: false
    t.string "name"
    t.integer "optimizations_count", default: 0, null: false
    t.integer "sheet_length"
    t.integer "sheet_width"
    t.boolean "template", default: false, null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["archived_at"], name: "index_projects_on_archived_at"
    t.index ["token"], name: "index_projects_on_token", unique: true
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "report_issues", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "page_url"
    t.datetime "replied_at"
    t.bigint "replied_by_id"
    t.text "reply_body"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["replied_by_id"], name: "index_report_issues_on_replied_by_id"
    t.index ["user_id"], name: "index_report_issues_on_user_id"
  end

  create_table "scan_tokens", force: :cascade do |t|
    t.decimal "cost_usd", precision: 8, scale: 4
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "image_type"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.bigint "project_id"
    t.jsonb "result"
    t.string "status", default: "pending", null: false
    t.jsonb "submitted_pieces"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_scan_tokens_on_expires_at"
    t.index ["project_id"], name: "index_scan_tokens_on_project_id"
    t.index ["token"], name: "index_scan_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_scan_tokens_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.datetime "discarded_at"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.boolean "internal", default: false, null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_city"
    t.string "last_sign_in_country"
    t.string "last_sign_in_device"
    t.string "last_sign_in_ip"
    t.string "locale"
    t.datetime "locked_at"
    t.string "plan", default: "free", null: false
    t.datetime "plan_expires_at"
    t.string "provider"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.datetime "terms_accepted_at"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_users_on_discarded_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["plan"], name: "index_users_on_plan"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "coupon_redemptions", "coupons"
  add_foreign_key "coupon_redemptions", "users"
  add_foreign_key "optimizations", "projects"
  add_foreign_key "optimizations", "scan_tokens"
  add_foreign_key "projects", "users"
  add_foreign_key "report_issues", "admin_users", column: "replied_by_id"
  add_foreign_key "report_issues", "users"
  add_foreign_key "scan_tokens", "projects"
  add_foreign_key "scan_tokens", "users"
end
