module EpisodesHelper
  # The intensity as it is written everywhere: the number itself, its colour only reinforcing it
  # (calm, warm, red), and a filled badge for 9 and 10. Never a tinted chip, which vanishes on a
  # calendar column of the same tint.
  def intensity_mark(intensity)
    return if intensity.nil?

    if intensity >= 9
      tag.span(intensity, class: "inline-flex min-w-7 items-center justify-center rounded-full bg-sev-extreme px-1.5 font-bold text-sev-on-extreme", data: { severity: "extreme" })
    else
      severity, weight = case intensity
                         when 0..3 then ["mild", "font-semibold"]
                         when 4..6 then ["moderate", "font-semibold"]
                         else ["severe", "font-bold"]
                         end
      tag.span(intensity, class: "#{weight} text-sev-#{severity}", data: { severity: severity })
    end
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
