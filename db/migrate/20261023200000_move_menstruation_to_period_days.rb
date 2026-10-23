# Menstruation is a property of the day, not of an episode: a period day without any headache still
# matters (the menstrual window around it is what makes a migraine "menstrual").
class MoveMenstruationToPeriodDays < ActiveRecord::Migration[8.1]
  def up
    create_table :period_days do |t|
      t.references :user, null: false, foreign_key: true
      t.date :date, null: false
      t.timestamps
    end
    add_index :period_days, %i[user_id date], unique: true

    execute <<~SQL
      INSERT INTO period_days (user_id, date, created_at, updated_at)
      SELECT DISTINCT user_id, occurred_on, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM episodes WHERE on_period = 1
    SQL

    remove_column :episodes, :on_period
  end

  def down
    add_column :episodes, :on_period, :boolean, null: false, default: false
    execute <<~SQL
      UPDATE episodes SET on_period = 1
      WHERE EXISTS (SELECT 1 FROM period_days WHERE period_days.user_id = episodes.user_id AND period_days.date = episodes.occurred_on)
    SQL
    drop_table :period_days
  end
end
