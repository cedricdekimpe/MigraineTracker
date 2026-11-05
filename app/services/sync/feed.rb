# frozen_string_literal: true

module Sync
  # What changed in a journal since a moment, for the mobile app (GET /api/v1/changes). Records are sent whole;
  # the app replaces its copy by uuid, so receiving one twice does no harm.
  class Feed
    # A record saved while the previous feed was being read may carry a slightly earlier time: read a little
    # before the cursor rather than miss it
    OVERLAP = 5.seconds

    def initialize(user, since:)
      @user = user
      @since = since
    end

    def as_json(*)
      cursor = Time.current
      {
        cursor: cursor.iso8601(6),
        full: @since.nil?,
        episodes: changed(@user.episodes.includes(:medication_intakes, :episode_triggers)).map { |e| Sync::Records.episode(e) },
        period_days: changed(@user.period_days).map { |day| Sync::Records.period_day(day) },
        daily_checks: changed(@user.daily_checks).map { |check| Sync::Records.daily_check(check) },
        deletions: deletions.map { |d| { type: Sync::Records::TYPE_NAMES.key(d.record_type), uuid: d.uuid, deleted_at: d.deleted_at.iso8601(6) } },
        # Small lists, always sent whole: what the crisis screen offers
        medications: @user.medications.alphabetical.map { |m| Sync::Records.medication(m) },
        triggers: @user.triggers.alphabetical.map { |t| { id: t.id, name: t.name, key: t.key } }
      }
    end

    private

    def changed(scope)
      @since ? scope.where(updated_at: (@since - OVERLAP)..) : scope
    end

    def deletions
      @since ? @user.deletions.where(deleted_at: (@since - OVERLAP)..) : Deletion.none
    end
  end
end
