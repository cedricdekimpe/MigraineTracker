require "test_helper"

class EpisodeTest < ActiveSupport::TestCase
  def build(attributes = {})
    users(:one).episodes.new({ occurred_on: Date.current, pain_kind: "migraine", intensity: 5 }.merge(attributes))
  end

  test "a migraine with an intensity is valid" do
    assert build.valid?
  end

  test "aura alone is valid and needs no intensity" do
    episode = build(pain_kind: nil, intensity: nil, aura: true)
    assert episode.valid?, episode.errors.full_messages.to_sentence
  end

  test "an aura can precede a migraine or a headache" do
    assert build(aura: true).valid?
    assert build(aura: true, pain_kind: "headache").valid?
  end

  test "needs an aura or a pain" do
    episode = build(pain_kind: nil, intensity: nil, aura: false)
    assert_not episode.valid?
    assert_includes episode.errors.full_messages.to_sentence, "aura"
  end

  test "pain requires an intensity between 1 and 10" do
    assert_not build(intensity: nil).valid?
    assert_not build(intensity: 0).valid?
    assert_not build(intensity: 11).valid?
    assert build(intensity: 1).valid?
    assert build(intensity: 10).valid?
  end

  test "intensity is dropped when there is no pain" do
    episode = build(pain_kind: "", intensity: 8, aura: true)
    episode.valid?
    assert_nil episode.intensity
    assert_nil episode.pain_kind
  end

  test "unknown pain kinds are rejected" do
    assert_not build(pain_kind: "strong").valid?
  end

  test "duration is optional but bounded" do
    assert build(duration_minutes: nil).valid?
    assert build(duration_minutes: 90).valid?
    assert_not build(duration_minutes: 0).valid?
    assert_not build(duration_minutes: Episode::MAX_DURATION_MINUTES + 1).valid?
  end

  test "several episodes can happen on the same day" do
    day = episodes(:migraine_with_aura).occurred_on
    assert_equal 2, users(:one).episodes.where(occurred_on: day).count
    assert build(occurred_on: day).save
  end

  test "code summarises pain and aura" do
    assert_equal "MA", episodes(:migraine_with_aura).code
    assert_equal "H", episodes(:headache).code
    assert_equal "A", episodes(:aura_only).code
    assert_equal "M", episodes(:second_same_day).code
  end

  test "cannot use another user's trigger" do
    episode = build
    episode.triggers << triggers(:other_users_trigger)
    assert_not episode.valid?
  end

  test "intakes are created through nested attributes and blank ones ignored" do
    episode = build(medication_intakes_attributes: [
      { medication_id: medications(:ibuprofen).id, dose: " 200 mg ", effect: "good" },
      { medication_id: "", dose: "ignored" }
    ])
    assert episode.save
    assert_equal 1, episode.medication_intakes.count
    assert_equal "200 mg", episode.medication_intakes.first.dose
  end

  test "cannot take another user's medication" do
    episode = build(medication_intakes_attributes: [{ medication_id: medications(:aspirin).id }])
    assert_not episode.save
  end

  test "destroying an episode removes its intakes and trigger links" do
    episode = episodes(:migraine_with_aura)
    assert_difference ["MedicationIntake.count", "EpisodeTrigger.count"], -2 do
      episode.destroy
    end
  end

  test "for_month selects the month" do
    month = episodes(:migraine_with_aura).occurred_on
    assert_includes users(:one).episodes.for_month(month), episodes(:migraine_with_aura)
    assert_not_includes users(:one).episodes.for_month(month - 3.months), episodes(:migraine_with_aura)
  end
end
