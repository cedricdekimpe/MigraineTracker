# An episode started with "I have a headache now" stays ongoing until "it's over".
class AddOngoingToEpisodes < ActiveRecord::Migration[8.1]
  def change
    add_column :episodes, :ongoing, :boolean, null: false, default: false
    add_index :episodes, [ :user_id, :ongoing ]
  end
end
