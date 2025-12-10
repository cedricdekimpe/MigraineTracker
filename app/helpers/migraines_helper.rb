module MigrainesHelper
  def migraine_cell_classes(day, current_month)
    classes = ["px-3 py-2 text-center text-sm border border-slate-200"]

    pastel_class, darker_class = palette_for(current_month)
    classes << (day.odd? ? pastel_class : darker_class)

    text_class = "text-slate-900"

    max_day = current_month.end_of_month.day
    if day > max_day
      classes << "opacity-40"
      text_class = "text-slate-400"
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
end
