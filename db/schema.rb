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

ActiveRecord::Schema.define(version: 2022_11_28_155635) do

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
    t.index ["actor"], name: "index_contacts_on_actor", unique: true
    t.index ["address"], name: "index_contacts_on_address", unique: true
    t.index ["key_id"], name: "index_contacts_on_key_id", unique: true
    t.index ["user_id"], name: "index_contacts_on_user_id", unique: true
  end

  create_table "followers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.integer "contact_id"
    t.text "follow_object"
    t.index ["user_id", "contact_id"], name: "index_followers_on_user_id_and_contact_id", unique: true
  end

  create_table "followings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.integer "contact_id"
    t.text "follow_object"
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
    t.string "conversation"
    t.text "foreign_object_json"
    t.datetime "note_modified_at"
    t.string "public_id"
    t.index ["contact_id"], name: "index_notes_on_contact_id"
    t.index ["conversation"], name: "index_notes_on_conversation"
    t.index ["import_id"], name: "index_notes_on_import_id", unique: true
    t.index ["parent_note_id"], name: "index_notes_on_parent_note_id"
    t.index ["public_id"], name: "index_notes_on_public_id", unique: true
  end

  create_table "queue_entries", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "next_try_at"
    t.integer "tries"
    t.integer "user_id"
    t.integer "contact_id"
    t.string "action"
    t.text "object_json"
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
