# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/AbcSize
def create_schema!
  ActiveRecord::Schema.define(version: 0) do
    create_table :forums do |t|
      t.string :name
      t.references :parent
    end
    add_foreign_key :forums, :forums, column: :parent_id, on_delete: :cascade

    create_table :users do |t|
      t.string     :login
      t.string     :email
      t.string     :password
      t.references :forum, foreign_key: { on_delete: :cascade }
      t.timestamps null: false
    end

    create_table :profiles do |t|
      t.references :user, foreign_key: { on_delete: :cascade }
      t.string     :name
      t.string     :title
    end

    create_table :questions do |t|
      t.references :forum, foreign_key: { on_delete: :cascade }
      t.string     :name
      t.integer    :rating, default: 0, null: false
      t.text       :text
      t.references :author
      t.timestamps null: false
    end
    add_foreign_key :questions, :users, column: :author_id, on_delete: :nullify

    create_table :answers do |t|
      t.references :question, foreign_key: { on_delete: :cascade }
      t.boolean    :best, default: false
      t.text       :text
      t.references :author
      t.timestamps null: false
    end
    add_foreign_key :answers, :users, column: :author_id, on_delete: :nullify

    create_table :tracking_pixels do |t|
      t.references :forum, foreign_key: { on_delete: :cascade }
    end

    create_table :votes do |t|
      t.references :votable, polymorphic: true
      t.references :user, foreign_key: { on_delete: :nullify }
    end

    create_table :roles do |t|
      t.string :name
      t.string :permissions, array: true
    end

    create_table :user_roles, id: false do |t|
      t.references :user, foreign_key: { on_delete: :cascade }
      t.references :role, foreign_key: { on_delete: :cascade }
      t.index %i[user_id role_id], unique: true
    end
  end
end
