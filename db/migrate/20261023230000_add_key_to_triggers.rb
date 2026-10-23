# The default triggers were stored as words in the language of the sign-up, so an account created in
# English kept "Lack of sleep" in the French interface. They now keep a key and are shown translated.
class AddKeyToTriggers < ActiveRecord::Migration[8.1]
  KNOWN = %w[stress lack_of_sleep alcohol skipped_meal caffeine weather screens strong_smells].freeze

  def up
    add_column :triggers, :key, :string
    add_index :triggers, %i[user_id key], unique: true, where: "key IS NOT NULL"

    names = Hash.new { |hash, name| hash[name] = nil }
    %i[fr en].each do |locale|
      KNOWN.each { |key| names[I18n.t("triggers.defaults.#{key}", locale: locale, default: key).downcase] = key }
    end
    select_all("SELECT id, user_id, name FROM triggers").each do |row|
      key = names[row["name"].to_s.strip.downcase]
      next unless key
      next if select_value("SELECT 1 FROM triggers WHERE user_id = #{row['user_id'].to_i} AND key = #{connection.quote(key)}")

      execute "UPDATE triggers SET key = #{connection.quote(key)} WHERE id = #{row['id'].to_i}"
    end
  end

  def down
    remove_index :triggers, %i[user_id key]
    remove_column :triggers, :key
  end
end
