# frozen_string_literal: true

module MyMigraineManager
  # The release, as tagged (vX.Y.Z): bump it in the commit that is tagged. The mobile app reads it from
  # /.well-known/migraine-tracker.json to know what this server can do.
  VERSION = "1.3.0"

  # The oldest mobile app release this server still works with
  MINIMUM_APP_VERSION = "1.0.0"
end
