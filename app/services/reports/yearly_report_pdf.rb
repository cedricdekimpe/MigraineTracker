# frozen_string_literal: true

require "prawn"
require "prawn/table"

module Reports
  # The report to hand to a neurologist. It reproduces the paper calendar they know (three months
  # per landscape page, in yellow / pink / blue, with the four rows and the legend) and starts with
  # one summary page of the figures they read: days with pain, migraine days, treatment days by
  # class, and the medication-overuse status of each month.
  class YearlyReportPdf
    PAGE_MARGIN = 24
    INK = "242126"
    MUTED = "756C5F"
    BLUE = "1E6482" # the lettering of the paper calendar
    RED = "B0342C"

    PALETTES = {
      "amber" => { frame: "E0A318", light: "FDF0C8", dark: "FAE296" },
      "rose" => { frame: "D0427D", light: "F9DBE9", dark: "F3BED7" },
      "sky" => { frame: "429DC2", light: "D7ECF5", dark: "B6DDED" }
    }.freeze

    STATUS_FILL = { ok: nil, advised: "FDF0C8", over: "FBE0DC", sustained: "F6C7C0" }.freeze

    attr_reader :user, :year

    def initialize(user:, year:, today: Date.current)
      @user = user
      @year = year
      @today = today
      @months = (1..12).map { |month| Date.new(year, month, 1) }
      @sheet = Sheet.new(user, months: @months)
      @overview = MonthlyOverview.new(user, months: 12, today: Date.new(year, 12, 31))
    end

    def render
      document.render
    end

    private

    def t(key, **options)
      I18n.t("report.#{key}", **options)
    end

    def document
      @document ||= Prawn::Document.new(page_layout: :landscape, margin: PAGE_MARGIN, info: { Title: "#{t('title')} #{year}", Creator: "Migraine Tracker" }) do |pdf|
        pdf.font "Helvetica"
        draw_summary(pdf)
        draw_indicators(pdf) if indicators?
        quarters.each do |quarter|
          pdf.start_new_page
          draw_quarter(pdf, quarter)
        end
        draw_footers(pdf)
      end
    end

    # Quarters up to the current one for the running year, the four of them for past years.
    def quarters
      all = @months.each_slice(3).to_a
      year == @today.year ? all.select { |quarter| quarter.first <= @today } : all
    end

    # --- summary page ----------------------------------------------------------

    def draw_summary(pdf)
      pdf.fill_color INK
      pdf.text "#{t('title')} - #{year}", size: 20, style: :bold
      pdf.fill_color MUTED
      pdf.text t("summary_subtitle"), size: 10
      pdf.move_down 12

      pdf.fill_color INK
      rows = [summary_header] + @overview.months.map { |month| summary_row(month) } + [summary_totals]
      pdf.table(rows, header: true, width: pdf.bounds.width, cell_style: { size: 9, padding: [5, 6], border_color: "E8DFCF", text_color: INK }) do |table|
        table.row(0).font_style = :bold
        table.row(0).background_color = "F5EFE3"
        table.row(-1).font_style = :bold
        table.row(-1).background_color = "F5EFE3"
        table.columns(1..-2).align = :center
        table.column(-1).align = :left
        table.column(0).width = 125

        @overview.months.each_with_index do |month, index|
          fill = STATUS_FILL[month.overuse_status]
          table.row(index + 1).column(-1).background_color = fill if fill
          table.row(index + 1).text_color = MUTED if month.month > @today
        end
      end

      pdf.move_down 12
      pdf.fill_color MUTED
      pdf.text t("overuse_note", triptan: MonthlyOverview::TRIPTAN_LIMIT, combination: MonthlyOverview::COMBINATION_LIMIT, acute: MonthlyOverview::ACUTE_LIMIT, mixed: MonthlyOverview::MIXED_LIMIT, acute_advised: MonthlyOverview::ACUTE_ADVISED, triptan_advised: MonthlyOverview::TRIPTAN_ADVISED), size: 8.5, leading: 2
      pdf.move_down 4
      pdf.text t("disclaimer"), size: 8.5, style: :italic
    end

    def summary_header
      %w[month pain_days migraine_days headache_days aura_days triptan_days acute_days treatment_days status].map { |key| t("columns.#{key}") }
    end

    def summary_row(month)
      return [l_month(month.month)] + ["-"] * 8 if month.month > @today

      [
        l_month(month.month), month.pain_days, month.migraine_days, month.headache_days, month.aura_days,
        month.triptan_days, month.non_triptan_days, month.any_acute_days, t("status.#{month.overuse_status}")
      ]
    end

    def summary_totals
      done = @overview.months.reject { |month| month.month > @today }
      average = done.empty? ? "-" : ActiveSupport::NumberHelper.number_to_rounded(done.sum(&:pain_days).to_f / done.size, precision: 1, strip_insignificant_zeros: true, locale: I18n.locale)
      [t("average_label"), average, "", "", "", "", "", "", ""]
    end

    def l_month(date)
      I18n.l(date, format: "%B").capitalize
    end

    # --- indicators page -------------------------------------------------------

    # Only when there is something to read: treatments taken, a preventive, a pattern worth a line.
    def indicators?
      insights.acute_rows.any? || insights.preventive_rows.any? || @overview.chronic_streak.positive? || menstrual_link
    end

    def insights
      @insights ||= TreatmentInsights.new(user, today: [@today, Date.new(year, 12, 31)].min, since: Date.new(year, 1, 1), through: Date.new(year, 12, 31))
    end

    def menstrual_link
      user.track_cycle? ? insights.menstrual_link : nil
    end

    def draw_indicators(pdf)
      pdf.start_new_page
      pdf.fill_color INK
      pdf.text "#{t('indicators_title')} - #{year}", size: 20, style: :bold
      pdf.fill_color MUTED
      pdf.text t("indicators_subtitle"), size: 10
      pdf.move_down 10

      done = @overview.months.reject { |month| month.month > @today }
      severe = done.sum(&:severe_days)
      pdf.fill_color INK
      pdf.text t("severe_line", total: severe, threshold: MonthlyOverview::SEVERE_FROM), size: 10
      pdf.text(t(@overview.chronic_streak >= 3 ? "chronic_sustained" : "chronic_month"), size: 10, style: :bold, color: RED) if @overview.chronic_streak.positive?
      pdf.move_down 10

      draw_acute_table(pdf) if insights.acute_rows.any?
      draw_preventive_table(pdf) if insights.preventive_rows.any?
      draw_menstrual(pdf) if menstrual_link

      pdf.fill_color MUTED
      pdf.move_down 6
      pdf.text t("disclaimer"), size: 8.5, style: :italic
    end

    def draw_acute_table(pdf)
      pdf.fill_color INK
      pdf.text t("acute_title"), size: 12, style: :bold
      pdf.move_down 4
      rows = [%w[medication intakes none partial good verdict].map { |key| t("acute_columns.#{key}") }] + insights.acute_rows.map do |row|
        [row.medication.name, row.intakes, row.none, row.partial, row.good, t("verdicts.#{row.verdict}")]
      end
      pdf.table(rows, header: true, width: pdf.bounds.width, cell_style: { size: 9, padding: [4, 6], border_color: "E8DFCF", text_color: INK }) do |table|
        table.row(0).font_style = :bold
        table.row(0).background_color = "F5EFE3"
        table.columns(1..4).align = :center
        table.column(0).width = 170
        insights.acute_rows.each_with_index { |row, index| table.row(index + 1).column(-1).background_color = "FBE0DC" if row.verdict == :not_working }
      end
      if (delay = insights.median_delay)
        pdf.move_down 4
        pdf.fill_color MUTED
        pdf.text t("delay_line", minutes: delay[:minutes], count: delay[:attacks]), size: 9
      end
      pdf.move_down 10
    end

    def draw_preventive_table(pdf)
      pdf.fill_color INK
      pdf.text t("preventive_title"), size: 12, style: :bold
      pdf.move_down 4
      rows = [%w[medication period dose stop before_after].map { |key| t("preventive_columns.#{key}") }] + insights.preventive_rows.map do |row|
        period = row.period
        range = "#{I18n.l(period.started_on, format: :short)} - #{period.current? ? t('ongoing') : I18n.l(period.ended_on, format: :short)}"
        change = row.before && row.after ? "#{format_number(row.before)} > #{format_number(row.after)}#{" (-#{(row.drop * 100).round} %)" if row.drop && row.drop.positive?}" : "-"
        [period.medication.name, range, period.dose.to_s, (I18n.t("treatment_periods.reasons.#{period.stop_reason}") if period.stop_reason).to_s, change]
      end
      pdf.table(rows, header: true, width: pdf.bounds.width, cell_style: { size: 9, padding: [4, 6], border_color: "E8DFCF", text_color: INK }) do |table|
        table.row(0).font_style = :bold
        table.row(0).background_color = "F5EFE3"
      end
      pdf.move_down 4
      pdf.fill_color MUTED
      pdf.text t("preventive_note"), size: 8.5
      pdf.move_down 10
    end

    def draw_menstrual(pdf)
      link = menstrual_link
      pdf.fill_color INK
      pdf.text t("menstrual_title"), size: 12, style: :bold
      pdf.move_down 2
      pdf.text t("menstrual_line", with_attack: link.with_attack, cycles: link.cycles), size: 10
      pdf.text(t("menstrual_pure"), size: 10) if link.pure?
      pdf.move_down 8
    end

    def format_number(value)
      ActiveSupport::NumberHelper.number_to_rounded(value, precision: 1, strip_insignificant_zeros: true, locale: I18n.locale)
    end

    # --- sheet pages -----------------------------------------------------------

    def draw_quarter(pdf, quarter)
      pdf.fill_color INK
      pdf.text "#{t('title')} - #{year}", size: 13, style: :bold
      pdf.move_down 6

      quarter.each { |month| draw_month(pdf, month) }
      draw_legend(pdf)
    end

    def draw_month(pdf, month)
      palette = PALETTES.fetch(%w[amber rose sky][(month.month - 1) % 3])
      rows = [:type, :intensity]
      rows << :cycle if user.track_cycle?
      rows << :treatment

      label_w = 96.0
      day_w = (pdf.bounds.width - 16 - label_w) / 31
      head_h = 14.0
      row_h = 30.0
      frame_h = 22 + head_h + rows.size * row_h + 8
      pdf.start_new_page if pdf.cursor < frame_h + 70

      left = pdf.bounds.left
      top = pdf.cursor
      grid_left = left + 8 + label_w

      # dashed frame in the month's ink, like the cut-out boxes of the sheet
      pdf.stroke_color palette[:frame]
      pdf.line_width 1
      pdf.dash 4, space: 3
      pdf.stroke_rounded_rectangle([left, top], pdf.bounds.width, frame_h, 8)
      pdf.undash

      pdf.fill_color INK
      pdf.text_box "#{t('name_label')} ................................................", at: [left + 10, top - 6], size: 8.5, width: 300, height: 12
      pdf.text_box "#{t('month_label')} #{I18n.l(month, format: '%B %Y')}", at: [left + pdf.bounds.width - 230, top - 5], size: 10, style: :bold, width: 220, height: 14, align: :right

      grid_top = top - 22
      days_in_month = month.end_of_month.day
      (1..31).each do |number|
        x = grid_left + (number - 1) * day_w
        fill = number > days_in_month ? "F8F5EE" : (number.odd? ? palette[:dark] : palette[:light])
        pdf.fill_color fill
        pdf.fill_rectangle [x, grid_top], day_w, head_h + rows.size * row_h
        pdf.fill_color(number > days_in_month ? "C9C0B0" : INK)
        pdf.text_box number.to_s, at: [x, grid_top - 3], width: day_w, height: head_h, size: 7, align: :center, style: :bold
      end

      rows.each_with_index do |row, index|
        y = grid_top - head_h - index * row_h
        pdf.fill_color INK
        pdf.text_box t("rows.#{row}"), at: [left + 10, y - 3], width: label_w - 4, height: row_h, size: 7.5, style: :bold, valign: :center
        @sheet.days_of(month).each do |day|
          text, color = cell_text(day, row)
          next if text.blank?

          x = grid_left + (day.date.day - 1) * day_w
          pdf.fill_color color
          pdf.text_box text, at: [x, y - 3], width: day_w, height: row_h - 4, size: 10, style: :bold, align: :center, valign: :center
        end
      end

      pdf.move_cursor_to top - frame_h - 8
    end

    def cell_text(day, row)
      return [nil, BLUE] unless day.any?

      case row
      when :type then [day.letter && (day.aura_with_pain? ? "#{day.letter}a" : day.letter), BLUE]
      when :intensity then [day.intensity&.to_s, day.intensity.to_i >= 7 ? RED : BLUE]
      when :cycle then [("0" if day.cycle?), BLUE]
      when :treatment then [[("X" if day.acute?), ("t" if day.triptan?)].compact.join(" "), BLUE]
      end
    end

    def draw_legend(pdf)
      items = %w[migraine headache aura].zip(%w[M T A]).map { |key, letter| "#{letter} = #{t("legend.#{key}")}" }
      items << "Ma / Ta = #{t('legend.aura_with_pain')}"
      items << "0-10 = #{t('legend.intensity')}"
      items << "0 = #{t('legend.cycle')}" if user.track_cycle?
      items << "X = #{t('legend.acute')}"
      items << "t = #{t('legend.triptan')}"

      pdf.fill_color MUTED
      pdf.text_box "#{t('legend.title')} :  #{items.join('   -   ')}", at: [pdf.bounds.left, pdf.cursor], width: pdf.bounds.width, size: 7.5, leading: 2
    end

    # --- footers ---------------------------------------------------------------

    def draw_footers(pdf)
      pdf.page_count.times do |index|
        pdf.go_to_page(index + 1)
        pdf.fill_color MUTED
        pdf.text_box "Migraine Tracker - #{t('generated_on', date: I18n.l(@today, format: :long))}", at: [pdf.bounds.left, pdf.bounds.bottom - 6], size: 7, width: 400
        pdf.text_box "#{index + 1} / #{pdf.page_count}", at: [pdf.bounds.right - 60, pdf.bounds.bottom - 6], size: 7, width: 60, align: :right
      end
    end
  end
end
