# The "get started" card of the journal. Accounts that exist already never see it: it is marked as dismissed.
class AddOnboardingDismissedAtToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :onboarding_dismissed_at, :datetime
    execute "UPDATE users SET onboarding_dismissed_at = CURRENT_TIMESTAMP"
  end

  def down
    remove_column :users, :onboarding_dismissed_at
  end
end
