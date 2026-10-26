# The crisis a visitor logs before having an account. It lives in the (encrypted) session cookie and
# is handed to the account at sign-in or sign-up: added to an existing journal, or the first entry of a
# new one. Nothing is stored server-side for someone who never signs in.
class GuestEpisode
  SESSION_KEY = "guest_episode"
  # A guest crisis this recent is still going on when the account picks it up.
  STILL_ONGOING_FOR = 12.hours

  # Session attributes for the submitted tap, or nil when it is not a valid crisis.
  def self.build(params, now: Time.current)
    attributes =
      if params[:aura_only].present?
        { "aura" => true }
      else
        { "pain_kind" => params[:pain_kind].to_s, "intensity" => params[:intensity].to_i, "aura" => params[:aura] == "1" }
      end
    attributes["at"] = now.iso8601

    probe = Episode.new(attributes.slice("aura", "pain_kind", "intensity").merge(occurred_on: now.to_date))
    probe.valid?
    attributes if (probe.errors.attribute_names - [ :user ]).empty?
  end

  def self.read(session)
    data = session[SESSION_KEY]
    data if data.is_a?(Hash) && data["at"].present?
  end

  def self.clear(session)
    session.delete(SESSION_KEY)
  end

  # Turns the stored crisis into an episode of +user+ and forgets it. Returns the episode, or nil.
  def self.claim(session, user, now: Time.current)
    data = read(session)
    clear(session)
    save(data, user, now: now) if data
  end

  # Turns crisis attributes (as made by build) into an episode of +user+: still going on if it began
  # less than 12 hours ago and no other is. Also used for the crises noted without network.
  # Returns the episode, or nil when it is invalid or already in the journal (the same crisis sent twice).
  def self.save(data, user, now: Time.current)
    at = Time.zone.parse(data["at"].to_s) or return
    attributes = { occurred_on: at.to_date, started_time: at.strftime("%H:%M"), aura: data["aura"] == true,
                   pain_kind: data["pain_kind"], intensity: data["intensity"] }
    return if user.episodes.exists?(attributes)

    ongoing = (now - at) < STILL_ONGOING_FOR && !user.episodes.ongoing.exists?
    episode = user.episodes.new(attributes.merge(ongoing: ongoing))
    episode if episode.save
  end
end
