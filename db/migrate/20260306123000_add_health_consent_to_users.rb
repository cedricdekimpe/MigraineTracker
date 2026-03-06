class AddHealthConsentToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :health_data_consent_given_at, :datetime
    add_column :users, :health_data_consent_version, :string
    add_column :users, :health_data_consent_text, :text
    add_index :users, :health_data_consent_version
  end
end
