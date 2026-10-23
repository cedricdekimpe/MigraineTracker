# Presentation of the paper calendar: month inks, shaded columns, the letters and marks of a day.
module SheetHelper
  TINTS = {
    "amber" => %w[bg-amber-100 bg-amber-200],
    "rose" => %w[bg-rose-100 bg-rose-200],
    "sky" => %w[bg-sky-100 bg-sky-200]
  }.freeze

  BORDERS = { "amber" => "border-amber-400", "rose" => "border-rose-400", "sky" => "border-sky-400" }.freeze

  # Dashed frame in the month's ink, like the sheet's cut-out boxes
  def sheet_frame_class(month)
    BORDERS.fetch(month_ink(month))
  end

  # Odd days are shaded darker, even days lighter, as on the paper
  def sheet_column_class(day_number, month)
    TINTS.fetch(month_ink(month))[day_number.odd? ? 1 : 0]
  end

  def sheet_title(months)
    "#{l(months.first, format: '%B')} – #{l(months.last, format: '%B %Y')}"
  end

  # "M", "T" or "A", with a small "a" when an aura came with the pain
  def sheet_letter(day)
    return if day.letter.nil?

    safe_join([day.letter, (tag.sup("a", class: "ml-px text-[0.6em] font-semibold", title: t("episodes.aura")) if day.aura_with_pain?)])
  end

  # Severity colouring of the written number: calm, then warm, then red
  def sheet_intensity_class(value)
    case value
    when 0..3 then "text-ink-800"
    when 4..6 then "text-amber-800 font-semibold"
    else "text-red-700 font-bold"
    end
  end

  # "X" and/or "t", as on the paper's "acute treatment" row
  def sheet_treatment(day)
    marks = []
    marks << tag.span("X", title: t("sheet.legend.acute")) if day.acute?
    marks << tag.span("t", title: t("sheet.legend.triptan")) if day.triptan?
    safe_join(marks, tag.span("·", class: "mx-px opacity-50"))
  end

  # Content of one cell of the sheet for a given row (:type, :intensity, :cycle, :treatment)
  def sheet_cell(day, row)
    case row
    when :type then sheet_letter(day)
    when :intensity then (tag.span(day.intensity, class: sheet_intensity_class(day.intensity)) if day.intensity)
    when :cycle then ("0" if day.cycle?)
    when :treatment then sheet_treatment(day)
    end
  end

  # The cycle-row tap: marks the day as a bleeding day, or unmarks it ("0" when marked).
  def period_toggle(day, size: "h-10", label: "0")
    date = day.date
    text = day.cycle? ? label : "·"
    classes = "flex #{size} w-full cursor-pointer items-center justify-center font-semibold #{day.cycle? ? 'text-rose-700' : 'text-ink-300 hover:text-ink-600'}"
    title = t(day.cycle? ? "sheet.period.unmark" : "sheet.period.mark", date: l(date, format: :long))
    if day.cycle?
      button_to text, period_day_path(date: date.iso8601), method: :delete, class: classes, title: title, "aria-label": title, form: { class: "contents", data: { turbo: false } }
    else
      button_to text, period_days_path(date: date.iso8601), method: :post, class: classes, title: title, "aria-label": title, form: { class: "contents", data: { turbo: false } }
    end
  end

  def sheet_future?(date)
    date > Date.current
  end

  def sheet_row_label(key)
    t("sheet.rows.#{key}")
  end
end
