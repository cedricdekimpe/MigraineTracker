# Nausea or vomiting during an attack (an ICHD-3 criterion, and a reason to choose another route or an
# antiemetic). Empty means "not said": older episodes, paper archives, guest entries.
class AddNauseaToEpisodes < ActiveRecord::Migration[8.1]
  def change
    add_column :episodes, :nausea, :string
    add_check_constraint :episodes, "nausea IS NULL OR nausea IN ('none', 'nausea', 'vomiting')", name: "episodes_nausea_values"
  end
end
