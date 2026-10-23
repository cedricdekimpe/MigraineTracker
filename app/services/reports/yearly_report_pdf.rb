# frozen_string_literal: true

require "prawn"
require "prawn/table"

module Reports
  class YearlyReportPdf
    attr_reader :user, :year, :months, :grouped_episodes, :days

    HEADER_COLOR = "E2E8F0"
    ATTR_TEXT_COLOR = "0F172A"
    EMPTY_TEXT_COLOR = "94A3B8"
    EMPTY_BACKGROUND = "F8FAFC"

    def initialize(user:, year:, months:, grouped_episodes:, days: (1..31).to_a)
      @user = user
      @year = year
      @months = months
      @grouped_episodes = grouped_episodes
      @days = days
    end

    def render
      document.render
    end

    private

    def document
      @document ||= Prawn::Document.new(page_layout: :landscape, margin: 24) do |pdf|
        months.each_slice(3).with_index do |month_group, group_index|
          pdf.start_new_page unless group_index.zero?
          build_page_header(pdf)

          month_group.each_with_index do |month, index|
            build_month_section(pdf, month)
            pdf.move_down 16 unless index == month_group.size - 1
          end
        end
      end
    end

    def build_page_header(pdf)
      pdf.text "Migraine Overview", size: 20, style: :bold, align: :left
      pdf.move_down 4
      pdf.text "Year: #{year}", size: 12
      pdf.text "Generated for #{user.email}", size: 10, color: "555555"
      pdf.move_down 8
      pdf.stroke_horizontal_rule
      pdf.move_down 12
    end

    def build_month_section(pdf, month)
      pdf.text month.strftime("%B"), size: 16, style: :bold, color: ATTR_TEXT_COLOR
      pdf.move_down 8

      entries = Array.wrap(grouped_episodes[month])
      entries_by_day = entries.group_by { |episode| episode.occurred_on.day }

      table_data = build_table_data(month, entries_by_day)
      render_calendar_table(pdf, month, table_data)
    end

    def build_table_data(month, entries_by_day)
      [table_header_row] + attribute_rows(month, entries_by_day)
    end

    def table_header_row
      ["Attribute"] + days.map(&:to_s)
    end

    def attribute_rows(month, entries_by_day)
      rows = [
        build_attribute_row("Type", month, entries_by_day) { |episodes| episodes.map(&:code).join(" ") },
        build_attribute_row("Intensity", month, entries_by_day) { |episodes| episodes.filter_map(&:intensity).max || "–" }
      ]
      if user.track_cycle?
        rows << build_attribute_row("Menstrual cycle", month, entries_by_day) { |episodes| episodes.any?(&:on_period?) ? "Yes" : "No" }
      end
      rows << build_attribute_row("Medication", month, entries_by_day) do |episodes|
        names = episodes.flat_map(&:medications).uniq.map(&:abbreviation)
        names.empty? ? "–" : names.first(2).join(" ") + (names.size > 2 ? " +" : "")
      end
      rows
    end

    # `yield` receives the day's episodes; days without episodes show a dash.
    def build_attribute_row(label, _month, entries_by_day)
      [label] + days.map do |day|
        episodes = entries_by_day[day]
        episodes.present? ? yield(episodes) : "–"
      end
    end

    def render_calendar_table(pdf, month, table_data)
      palette = palette_for(month)
      max_day = month.end_of_month.day

      pdf.table(table_data, header: true, width: pdf.bounds.width, cell_style: { size: 8, padding: [4, 4, 4, 4], inline_format: false, overflow: :shrink_to_fit, min_font_size: 6 }) do |table|
        table.cells.border_color = "E2E8F0"
        table.row(0).font_style = :bold
        table.row(0).background_color = HEADER_COLOR
        table.row(0).align = :center
        table.row(0).text_color = ATTR_TEXT_COLOR

        table.column(0).font_style = :bold
        table.column(0).text_color = ATTR_TEXT_COLOR
        table.column(0).width = 110
        table.column(0).align = :left
        table.cells.rows(1..-1).columns(0).style do |cell|
          cell.background_color = "FFFFFF"
          cell.text_color = ATTR_TEXT_COLOR
          cell.align = :left
        end

        decorate_day_cells(table, palette, max_day)
      end
    end

    def decorate_day_cells(table, palette, max_day)
      days.each_with_index do |day, day_index|
        column_index = day_index + 1

        if day > max_day
          style_empty_day_cells(table, column_index)
          next
        end

        background = background_for_day(day, palette)
        text_color = ATTR_TEXT_COLOR

        table.cells.rows(1..-1).columns(column_index).style do |cell|
          cell.background_color = background
          cell.text_color = text_color
          cell.align = :center
        end
      end
    end

    def style_empty_day_cells(table, column_index)
      table.cells.rows(1..-1).columns(column_index).style do |cell|
        cell.background_color = EMPTY_BACKGROUND
        cell.text_color = EMPTY_TEXT_COLOR
        cell.align = :center
      end
    end

    def background_for_day(day, palette)
      day.odd? ? palette.first : palette.last
    end

    def palette_for(month)
      case ((month.month - 1) % 3)
      when 0
        ["FEF3C7", "FDE68A"]
      when 1
        ["FFE4E6", "FDA4AF"]
      else
        ["E0F2FE", "BAE6FD"]
      end
    end
  end
end
