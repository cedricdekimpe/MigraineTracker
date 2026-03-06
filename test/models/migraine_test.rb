require "test_helper"

class MigraineTest < ActiveSupport::TestCase
  setup do
    @user = User.create!({
      email: "author@example.com",
      password: "password123",
      password_confirmation: "password123"
    }.merge(consent_attrs))
  end

  test "requires unique entry per user per day" do
    date = Date.new(2025, 12, 1)

    assert_difference -> { Migraine.count }, 1 do
      @user.migraines.create!(occurred_on: date, nature: "M", intensity: 5, on_period: false)
    end

    duplicate = @user.migraines.build(occurred_on: date, nature: "H", intensity: 3, on_period: false)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:occurred_on], "has already been taken"
  end

  test "validates intensity range" do
    migraine = @user.migraines.build(occurred_on: Date.current, nature: "M", intensity: 12, on_period: false)
    assert_not migraine.valid?
    assert_includes migraine.errors[:intensity], "must be less than or equal to 10"
  end

  test "medication must belong to user" do
    other_user = User.create!({
      email: "other@example.com",
      password: "password123",
      password_confirmation: "password123"
    }.merge(consent_attrs))
    foreign_medication = other_user.medications.first

    migraine = @user.migraines.build(occurred_on: Date.current, nature: "M", intensity: 4, on_period: false, medication: foreign_medication)

    assert_not migraine.valid?
    assert_includes migraine.errors[:medication], "must belong to you"
  end
end
