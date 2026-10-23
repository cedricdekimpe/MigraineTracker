# The REST API (JWT) and rails_admin were removed: nothing used them. Production held no real data.
class RemoveApiAndAdminTables < ActiveRecord::Migration[8.1]
  def change
    drop_table :jwt_denylist do |t|
      t.string :jti, null: false
      t.datetime :exp, null: false
      t.index :jti
    end

    remove_index :users, :admin, if_exists: true
    remove_column :users, :admin, :boolean, default: false, null: false
  end
end
