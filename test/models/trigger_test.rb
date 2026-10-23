require "test_helper"

class TriggerTest < ActiveSupport::TestCase
  test "names are unique per user ignoring case" do
    assert_not users(:one).triggers.new(name: "stress").valid?
    assert users(:two).triggers.new(name: "Chocolate").valid?
  end

  test "new users get the default triggers in their language" do
    I18n.with_locale(:fr) do
      user = User.create!({ email: "fr@example.com", password: "password123" }.merge(consent_attrs))
      assert_includes user.triggers.pluck(:name), "Manque de sommeil"
      assert_equal Trigger::DEFAULT_KEYS.size, user.triggers.count
    end
  end

  test "deleting a trigger removes it from episodes but keeps the episodes" do
    assert_no_difference "Episode.count" do
      assert_difference "EpisodeTrigger.count", -1 do
        triggers(:stress).destroy
      end
    end
  end

  test "default triggers keep their key and show in the language of the interface" do
    user = I18n.with_locale(:en) { User.create!({ email: "en@example.com", password: "password123" }.merge(consent_attrs)) }
    sleep_trigger = user.triggers.find_by!(key: "lack_of_sleep")
    assert_equal "Lack of sleep", sleep_trigger.name
    I18n.with_locale(:fr) { assert_equal "Manque de sommeil", sleep_trigger.display_name }
  end

  test "a typed name is matched to the default it stands for, in any language" do
    assert_equal "lack_of_sleep", Trigger.default_key_for(" manque de SOMMEIL ")
    assert_equal "lack_of_sleep", Trigger.default_key_for("Lack of sleep")
    assert_nil Trigger.default_key_for("Chocolate")
  end

  test "the same default cannot be added twice under another language" do
    user = I18n.with_locale(:en) { User.create!({ email: "en2@example.com", password: "password123" }.merge(consent_attrs)) }
    duplicate = user.triggers.new(name: "Manque de sommeil")
    assert_not duplicate.valid?
    assert user.triggers.new(name: "Chocolat").valid?
  end

  test "a trigger of one's own keeps its own word" do
    own = users(:two).triggers.create!(name: "Chocolate")
    assert_nil own.key
    I18n.with_locale(:fr) { assert_equal "Chocolate", own.display_name }
  end
end
