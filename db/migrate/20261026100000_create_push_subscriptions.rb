# Notifications sent to the phone or computer (web push). A subscription is one browser on one device that
# accepted them; it holds the address of the browser's push service and the keys that encrypt the message.
# The daily check-in reminder is off by default: an empty time means no reminder.
class CreatePushSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :push_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :endpoint, null: false
      t.string :p256dh, null: false
      t.string :auth, null: false
      t.string :locale, null: false, default: "fr"
      t.timestamps
    end
    add_index :push_subscriptions, :endpoint, unique: true

    add_column :users, :daily_reminder_at, :string
    add_column :users, :time_zone, :string, null: false, default: "Europe/Brussels"
    add_column :users, :daily_reminder_sent_on, :date
  end
end
