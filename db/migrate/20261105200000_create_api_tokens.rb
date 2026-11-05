# Signed-in devices of the mobile app: one opaque token each, stored as a digest, revocable from the account.
# The web code is a one-time, one-minute code that opens a web session for the app's web screens.
class CreateApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token_digest, null: false
      t.datetime :last_used_at
      t.string :web_code_digest
      t.datetime :web_code_expires_at
      t.timestamps
    end
    add_index :api_tokens, :token_digest, unique: true
    add_index :api_tokens, :web_code_digest, unique: true
  end
end
