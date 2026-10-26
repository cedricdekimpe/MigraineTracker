# "Still going?": a notification when an attack started with "I have a headache now" has been open for
# 12 hours, so that its duration is not left running. Off by default, sent once per episode.
class AddOngoingCheck < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :ongoing_check, :boolean, null: false, default: false
    add_column :episodes, :ongoing_checked_at, :datetime
  end
end
