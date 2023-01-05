# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2023_01_05_050019) do

  create_table "api_apps", force: :cascade do |t|
    t.string "client_name"
    t.string "redirect_uri"
    t.string "scopes"
    t.string "website"
    t.string "client_id"
    t.string "client_secret"
    t.string "vapid_key"
    t.index ["client_id"], name: "index_api_apps_on_client_id", unique: true
  end

  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "api_app_id"
    t.integer "user_id"
    t.string "scope"
    t.string "code"
    t.string "access_token"
    t.index ["access_token"], name: "index_api_tokens_on_access_token", unique: true
  end

  create_table "attachment_blobs", force: :cascade do |t|
    t.integer "attachment_id"
    t.binary "data"
    t.index ["attachment_id"], name: "index_attachment_blobs_on_attachment_id"
  end

  create_table "attachments", force: :cascade do |t|
    t.integer "note_id"
    t.string "type"
    t.integer "width"
    t.integer "height"
    t.integer "duration"
    t.string "source"
    t.string "summary"
    t.index ["note_id"], name: "index_attachments_on_note_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "actor"
    t.string "key_id"
    t.string "key_pem"
    t.string "inbox"
    t.string "url"
    t.string "realname"
    t.string "address"
    t.text "about"
    t.integer "avatar_attachment_id"
    t.integer "user_id"
    t.json "object"
    t.integer "header_attachment_id"
    t.datetime "last_refreshed_at"
    t.index ["actor"], name: "index_contacts_on_actor", unique: true
    t.index ["address"], name: "index_contacts_on_address", unique: true
    t.index ["key_id"], name: "index_contacts_on_key_id", unique: true
    t.index ["user_id"], name: "index_contacts_on_user_id", unique: true
  end

  create_table "conversations", force: :cascade do |t|
    t.string "public_id"
    t.index ["public_id"], name: "index_conversations_on_public_id"
  end

  create_table "followers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.integer "contact_id"
    t.json "follow_object"
    t.index ["user_id", "contact_id"], name: "index_followers_on_user_id_and_contact_id", unique: true
  end

  create_table "followings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.integer "contact_id"
    t.json "follow_object"
    t.index ["user_id", "contact_id"], name: "index_followings_on_user_id_and_contact_id", unique: true
  end

  create_table "forwards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "contact_id"
    t.integer "note_id"
    t.index ["note_id", "contact_id"], name: "index_forwards_on_note_id_and_contact_id", unique: true
  end

  create_table "keystores", primary_key: "key", id: :string, force: :cascade do |t|
    t.string "value", null: false
    t.datetime "expiration"
  end

  create_table "likes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "contact_id"
    t.integer "note_id"
    t.index ["note_id", "contact_id"], name: "index_likes_on_note_id_and_contact_id", unique: true
  end

  create_table "notes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "contact_id"
    t.string "note"
    t.integer "parent_note_id"
    t.text "import_id"
    t.json "object"
    t.datetime "note_modified_at"
    t.string "public_id"
    t.boolean "is_public", default: false
    t.json "mentioned_contact_ids"
    t.boolean "for_timeline", default: false
    t.integer "conversation_id"
    t.index ["contact_id"], name: "index_notes_on_contact_id"
    t.index ["conversation_id"], name: "index_notes_on_conversation_id"
    t.index ["for_timeline"], name: "index_notes_on_for_timeline"
    t.index ["import_id"], name: "index_notes_on_import_id", unique: true
    t.index ["is_public"], name: "index_notes_on_is_public"
    t.index ["parent_note_id"], name: "index_notes_on_parent_note_id"
    t.index ["public_id"], name: "index_notes_on_public_id", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at"
    t.string "type"
    t.integer "user_id"
    t.integer "note_id"
    t.integer "contact_id"
    t.index ["user_id", "note_id", "contact_id", "type"], name: "unique_notifications", unique: true
  end

  create_table "queue_entries", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "next_try_at"
    t.integer "tries"
    t.integer "user_id"
    t.integer "contact_id"
    t.string "action"
    t.json "object"
    t.integer "note_id"
    t.index ["contact_id"], name: "index_queue_entries_on_contact_id"
    t.index ["note_id"], name: "index_queue_entries_on_note_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username"
    t.string "password_digest"
    t.text "private_key"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

end
