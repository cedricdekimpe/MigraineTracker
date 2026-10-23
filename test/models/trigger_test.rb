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
end
