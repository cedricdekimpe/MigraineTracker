module ApplicationHelper
  include Pagy::Frontend

  def pagy_tailwind_nav(pagy)
    return "" if pagy.pages <= 1

    link = pagy_anchor(pagy)

    html = +%(<nav class="flex items-center justify-center gap-1" aria-label="Pagination">)

    # Previous button
    if pagy.prev
      html << link.call(pagy.prev, 
        '<svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/></svg>', 
        class: "inline-flex items-center rounded-md border border-slate-300 bg-white px-2 py-2 text-sm font-medium text-slate-500 hover:bg-slate-50 transition",
        aria: { label: "Previous" })
    else
      html << %(<span class="inline-flex items-center rounded-md border border-slate-200 bg-slate-50 px-2 py-2 text-sm font-medium text-slate-300 cursor-not-allowed"><svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/></svg></span>)
    end

    # Page numbers
    pagy.series.each do |item|
      case item
      when Integer
        html << link.call(item, item.to_s, 
          class: "inline-flex items-center rounded-md border border-slate-300 bg-white px-3 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50 transition")
      when String
        html << %(<span class="inline-flex items-center rounded-md border border-emerald-500 bg-emerald-500 px-3 py-2 text-sm font-medium text-white">#{item}</span>)
      when :gap
        html << %(<span class="inline-flex items-center px-2 py-2 text-sm font-medium text-slate-500">…</span>)
      end
    end

    # Next button
    if pagy.next
      html << link.call(pagy.next, 
        '<svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>', 
        class: "inline-flex items-center rounded-md border border-slate-300 bg-white px-2 py-2 text-sm font-medium text-slate-500 hover:bg-slate-50 transition",
        aria: { label: "Next" })
    else
      html << %(<span class="inline-flex items-center rounded-md border border-slate-200 bg-slate-50 px-2 py-2 text-sm font-medium text-slate-300 cursor-not-allowed"><svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg></span>)
    end

    html << %(</nav>)
    html.html_safe
  end
end
