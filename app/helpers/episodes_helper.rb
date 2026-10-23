module EpisodesHelper
  def intensity_color_class(intensity)
    case intensity
    when 0..3
      "bg-sky-100 text-sky-800"
    when 4..6
      "bg-amber-100 text-amber-800"
    when 7..8
      "bg-red-100 text-red-700"
    else
      "bg-red-600 text-white"
    end
  end

  def intensity_badge_class(intensity)
    intensity ? intensity_color_class(intensity) : "bg-ink-100 text-ink-600"
  end

  # "Migraine with aura", "Headache", "Aura without pain", ...
  def episode_kind_label(episode)
    key = if episode.pain?
      episode.aura? ? "#{episode.pain_kind}_aura" : episode.pain_kind
    else
      "aura_only"
    end
    t("episodes.kinds.#{key}")
  end

  # What a guest told us, worded like a saved episode: "Migraine, 7/10".
  def guest_episode_summary(data)
    episode = Episode.new(pain_kind: data["pain_kind"].presence, aura: data["aura"], intensity: data["intensity"])
    [episode_kind_label(episode), (episode.intensity && "#{episode.intensity}/10")].compact.join(", ")
  end

  # 135 -> "2 h 15", 45 -> "45 min"
  def duration_label(minutes)
    hours, rest = minutes.divmod(60)
    return "#{rest} min" if hours.zero?

    rest.zero? ? "#{hours} h" : "#{hours} h #{rest.to_s.rjust(2, '0')}"
  end

  def episode_time_label(episode)
    return unless episode.started_time

    label = l(episode.started_time, format: "%H:%M")
    label += " · #{duration_label(episode.duration_minutes)}" if episode.duration_minutes
    label
  end
end
