module EpisodesHelper
  def episode_cell_classes(day, current_month)
    classes = ["px-3 py-2 text-center text-sm border border-ink-200"]

    pastel_class, darker_class = palette_for(current_month)
    classes << (day.odd? ? pastel_class : darker_class)

    text_class = "text-ink-900"

    max_day = current_month.end_of_month.day
    if day > max_day
      classes << "opacity-40"
      text_class = "text-ink-400"
    end

    classes << text_class
    classes.join(" ")
  end

  def palette_for(month)
    case ((month.month - 1) % 3)
    when 0
      ["bg-amber-100", "bg-amber-200"]
    when 1
      ["bg-rose-100", "bg-rose-200"]
    else
      ["bg-sky-100", "bg-sky-200"]
    end
  end

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

  # Calendar cell: codes of every episode of the day, e.g. "MA" or "M · H".
  def day_codes(episodes)
    episodes.blank? ? "–" : episodes.map(&:code).join(" · ")
  end

  def day_intensity(episodes)
    values = Array(episodes).map(&:intensity).compact
    values.empty? ? "–" : values.max
  end

  def day_cycle(episodes)
    return "–" if episodes.blank?

    episodes.any?(&:on_period?) ? t("episodes.calendar.yes") : t("episodes.calendar.no")
  end

  def day_medications(episodes)
    medications = Array(episodes).flat_map(&:medications).uniq
    return "–" if medications.empty?

    safe_join(medications.first(3).map do |medication|
      content_tag(:span, medication.abbreviation,
        title: medication.name,
        class: "inline-flex min-w-6 items-center justify-center rounded-full bg-paper/60 px-1.5 py-0.5 text-xs font-semibold text-ink-700 ring-1 ring-inset ring-ink-200")
    end + (medications.size > 3 ? ["+#{medications.size - 3}"] : []), " ")
  end
end
