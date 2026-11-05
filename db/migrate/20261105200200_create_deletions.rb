# What was deleted, so that the app's other devices delete it too on their next sync.
class CreateDeletions < ActiveRecord::Migration[8.1]
  def change
    create_table :deletions do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :record_type, null: false
      t.string :uuid, null: false
      t.datetime :deleted_at, null: false
    end
    add_index :deletions, %i[user_id deleted_at]
  end
end
