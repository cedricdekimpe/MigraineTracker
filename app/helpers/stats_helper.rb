# SVG charts rendered on the server (no JavaScript, no third party). Colours come from the theme
# roles, so they follow Papier / Nuit. The month inks of the paper calendar (yellow, pink, blue) frame
# the month panel; they never encode data in a chart.
module StatsHelper
  MONTH_INKS = %w[amber rose sky].freeze

  def month_ink(date)
    MONTH_INKS[(date.month - 1) % 3]
  end

  # The month panel takes the sheet's dashed frame in the month's ink; tinted in Papier, plain in Nuit
  # (literal class names so Tailwind keeps them)
  def month_panel_class(date)
    {
      "amber" => "border-amber-400 bg-panel-amber",
      "rose" => "border-rose-400 bg-panel-rose",
      "sky" => "border-sky-400 bg-panel-sky"
    }.fetch(month_ink(date))
  end

  # Two renderings of the same chart: a wide one from tablet width, a compact one for phones
  # (same data, bigger text relative to the screen, one-letter month labels).
  def month_columns(months, **options)
    safe_join([
      tag.div(month_columns_svg(months, **options), class: "hidden sm:block"),
      tag.div(month_columns_svg(months, compact: true, **options), class: "sm:hidden")
    ])
  end

  # Column chart: one column per month. `segments` receives a month and returns the stacked values
  # bottom to top, e.g. [migraine_days, headache_days]; the first segment is chart-a, the next ones chart-b,
  # separated by a gap in the surface colour so they never rely on hue alone.
  def month_columns_svg(months, label:, segments:, threshold: nil, threshold_label: nil, compact: false)
    width = compact ? 340.0 : 600.0
    height = compact ? 210.0 : 220.0
    left = compact ? 22.0 : 26.0
    top = 20.0
    bottom = 34.0
    plot_w = width - left - 6
    plot_h = height - top - bottom

    stacks = months.map { |month| segments.call(month) }
    max = [stacks.map(&:sum).max.to_i, threshold.to_i, 6].max
    max += 1 if max.odd?
    slot = plot_w / months.size
    bar_w = slot * 0.62
    scale = ->(value) { plot_h * value / max }
    series = %w[chart-a chart-b]
    small = 12 # never below 12px, also on the compact phone chart

    parts = []
    [0, max / 2, max].each do |value|
      y = top + plot_h - scale.call(value)
      parts << tag.line(x1: left, x2: width - 6, y1: y, y2: y, style: "stroke: rgb(var(--line)); stroke-width: 1")
      parts << tag.text(value, x: left - 6, y: y + 4, "text-anchor": "end", style: "fill: rgb(var(--fg-muted)); font-size: #{small}px")
    end

    months.each_with_index do |month, index|
      x = left + index * slot + (slot - bar_w) / 2
      base = top + plot_h
      total = 0

      bars = stacks[index].each_with_index.map do |value, layer|
        next if value.to_i.zero?

        total += value
        base -= scale.call(value)
        tag.rect(x: x.round(1), y: base.round(1), width: bar_w.round(1), height: scale.call(value).round(1), rx: 3,
                 style: "fill: rgb(var(--#{series[layer] || series.last})); stroke: rgb(var(--surface)); stroke-width: 1.5")
      end

      title = tag.title("#{l(month.month, format: :month_year)} : #{stacks[index].sum}")
      parts << tag.g(safe_join([title, *bars.compact]))
      parts << tag.text(total, x: (x + bar_w / 2).round(1), y: (base - 5).round(1), "text-anchor": "middle", style: "fill: rgb(var(--fg-secondary)); font-size: #{small}px; font-weight: 600") if total.positive?

      current = index == months.size - 1
      month_label = compact ? l(month.month, format: "%b").first.upcase : l(month.month, format: "%b")
      parts << tag.text(month_label, x: (x + bar_w / 2).round(1), y: height - 16, "text-anchor": "middle",
                        style: "fill: rgb(var(--#{current ? 'fg' : 'fg-muted'})); font-size: #{small}px; font-weight: #{current ? 700 : 400}")
      if month.month.month == 1 || index.zero?
        parts << tag.text(month.month.year, x: (x + bar_w / 2).round(1), y: height - 3, "text-anchor": "middle", style: "fill: rgb(var(--fg-muted)); font-size: #{small}px")
      end
    end

    if threshold
      y = top + plot_h - scale.call(threshold)
      parts << tag.line(x1: left, x2: width - 6, y1: y, y2: y, style: "stroke: rgb(var(--red-500)); stroke-width: 1.5; stroke-dasharray: 5 4")
      parts << tag.text(threshold_label, x: width - 8, y: y - 5, "text-anchor": "end", style: "fill: rgb(var(--over-text)); font-size: #{small}px; font-weight: 600") if threshold_label
    end

    tag.svg(safe_join(parts), "viewBox" => "0 0 #{width.to_i} #{height.to_i}", role: "img", "aria-label": label, class: "h-auto w-full")
  end

  # A bar of days against a limit: calm blue, amber from the advised limit, red from the diagnostic threshold.
  # A tick marks the advised limit.
  def limit_meter(days:, limit:, advised: nil)
    ratio = days.to_f / limit
    fill = if days >= limit then "bg-meter-over"
           elsif advised && days >= advised then "bg-meter-advised"
           else "bg-meter-ok"
           end

    tag.div(class: "relative h-3 w-full overflow-hidden rounded-full bg-meter-track", role: "meter", "aria-valuemin": 0, "aria-valuemax": limit, "aria-valuenow": days) do
      bar = tag.div("", class: "h-3 rounded-full #{fill}", style: "width: #{[(ratio * 100).round, 100].min}%")
      tick = advised ? tag.span("", class: "absolute inset-y-0 w-0.5 bg-fg-muted", style: "left: #{(advised.to_f / limit * 100).round}%") : "".html_safe
      bar + tick
    end
  end
end
