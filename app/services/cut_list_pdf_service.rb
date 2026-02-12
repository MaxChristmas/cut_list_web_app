class CutListPdfService
  COLORS = %w[4299e1 48bb78 ed8936 9f7aea f56565 38b2ac ecc94b e53e9e 667eea dd6b20].freeze
  STOCK_BG = "f7fafc"
  STOCK_BORDER = "a0aec0"
  PIECE_BORDER = "2d3748"
  TEXT_COLOR = "1a202c"
  HEADER_COLOR = "c53030"
  MUTED_COLOR = "718096"
  LABEL_FONT = 7
  INFO_FONT = 8

  LEFT_COL_RATIO = 0.38
  RIGHT_COL_RATIO = 0.62
  COL_GAP = 12

  def initialize(result, project)
    @result = result
    @project = project
  end

  def generate
    Prawn::Document.new(page_size: "A4", margin: [30, 30, 40, 30]) do |pdf|
      @color_map = build_color_map
      @piece_summary = build_piece_summary

      draw_global_header(pdf)
      draw_sheets(pdf)
      draw_footer(pdf)
    end
  end

  private

  def t(key, **opts)
    I18n.t("pdf.#{key}", **opts)
  end

  # ── Global header ──────────────────────────────────────────────

  def draw_global_header(pdf)
    pdf.fill_color HEADER_COLOR
    pdf.font_size(14) do
      pdf.text(@project.name.presence || "Cut List", style: :bold)
    end
    pdf.move_down 8
    pdf.fill_color TEXT_COLOR

    left_w = pdf.bounds.width * 0.5
    right_w = pdf.bounds.width * 0.5
    top = pdf.cursor

    # Left: global stats
    pdf.bounding_box([0, top], width: left_w) do
      stock_area = stock[:l] * stock[:w]
      total_area = stock_area * sheets.size
      total_used = sheets.sum { |s| stock_area - s["waste_area"].to_f }
      total_waste = sheets.sum { |s| s["waste_area"].to_f }
      used_pct = total_area > 0 ? ((total_used / total_area) * 100).round(0) : 0
      waste_pct = total_area > 0 ? ((total_waste / total_area) * 100).round(0) : 0
      total_cuts = sheets.sum { |s| (s["placements"] || []).size }

      info_rows = [
        [t("sheets_used"), sheets.size.to_s],
        [t("total_area_used"), "#{total_used.round(0)} #{used_pct}%"],
        [t("total_waste_area"), "#{total_waste.round(0)} #{waste_pct}%"],
        [t("total_pieces"), total_cuts.to_s],
        [t("blade_kerf"), (@result["kerf"] || 0).to_s]
      ]
      draw_info_table(pdf, info_rows)
    end

    # Right: piece types + stock
    pdf.bounding_box([left_w, top], width: right_w) do
      pieces_text = @piece_summary.map { |k, q| "#{k} x#{q}" }.join("  ·  ")
      draw_info_table(pdf, [
        [t("pieces"), pieces_text],
        [t("stock_sheet"), "#{stock[:l].to_i}×#{stock[:w].to_i} x#{sheets.size}"]
      ])
    end

    pdf.move_cursor_to([pdf.cursor, top - 60].min)
    pdf.move_down 6
    pdf.stroke_color "dddddd"
    pdf.stroke_horizontal_rule
    pdf.move_down 10
  end

  # ── Per-sheet sections ─────────────────────────────────────────

  def draw_sheets(pdf)
    sheets.each_with_index do |sheet, i|
      pdf.start_new_page unless i.zero?

      page_w = pdf.bounds.width
      left_w = page_w * LEFT_COL_RATIO - COL_GAP / 2
      right_w = page_w * RIGHT_COL_RATIO - COL_GAP / 2
      right_x = page_w * LEFT_COL_RATIO + COL_GAP / 2
      top = pdf.cursor

      # ── Left column: sheet info + piece table ──
      pdf.bounding_box([0, top], width: left_w) do
        draw_sheet_info(pdf, sheet, i)
        pdf.move_down 8
        draw_piece_table(pdf, sheet)
      end

      left_bottom = pdf.cursor

      # ── Right column: visual layout ──
      pdf.bounding_box([right_x, top], width: right_w) do
        draw_sheet_layout(pdf, sheet, right_w)
      end

      right_bottom = pdf.cursor
      pdf.move_cursor_to([left_bottom, right_bottom].min)
    end
  end

  def draw_sheet_info(pdf, sheet, index)
    stock_area = stock[:l] * stock[:w]
    used_area = stock_area - sheet["waste_area"].to_f
    waste_area = sheet["waste_area"].to_f
    used_pct = ((used_area / stock_area) * 100).round(0)
    waste_pct = ((waste_area / stock_area) * 100).round(0)
    placements = sheet["placements"] || []
    unique_pieces = placements.map { |p| normalize_key(p["rect"]["w"], p["rect"]["h"]) }.uniq.size

    pdf.fill_color HEADER_COLOR
    pdf.font_size(11) do
      pdf.text t("sheet", number: index + 1), style: :bold
    end
    pdf.fill_color TEXT_COLOR
    pdf.move_down 4

    rows = [
      [t("stock_sheet"), "#{stock[:l].to_i}×#{stock[:w].to_i}"],
      [t("area_used"), "#{used_area.round(0)} #{used_pct}%"],
      [t("waste_area"), "#{waste_area.round(0)} #{waste_pct}%"],
      [t("pieces"), placements.size.to_s],
      [t("unique_sizes"), unique_pieces.to_s]
    ]
    draw_info_table(pdf, rows)
  end

  def draw_piece_table(pdf, sheet)
    placements = sheet["placements"] || []
    counts = Hash.new(0)
    placements.each { |p| counts[normalize_key(p["rect"]["w"], p["rect"]["h"])] += 1 }

    return if counts.empty?

    pdf.fill_color TEXT_COLOR
    pdf.font_size(LABEL_FONT) do
      header = [
        make_cell(t("piece"), :bold),
        make_cell(t("qty"), :bold)
      ]
      data = counts.map { |k, q| [k, q.to_s] }

      pdf.table([header] + data, width: pdf.bounds.width * 0.85) do |tbl|
        tbl.cells.padding = [2, 4, 2, 4]
        tbl.cells.borders = []
        tbl.cells.size = LABEL_FONT
        tbl.row(0).borders = [:bottom]
        tbl.row(0).border_width = 0.5
        tbl.row(0).border_color = "cccccc"
        tbl.columns(1).align = :right
      end
    end
  end

  # ── Sheet visual layout ────────────────────────────────────────

  def draw_sheet_layout(pdf, sheet, available_w)
    scale = available_w / stock[:l].to_f
    layout_h = stock[:w] * scale

    max_h = pdf.cursor - 20
    if layout_h > max_h && max_h > 0
      scale = max_h / stock[:w].to_f
      layout_h = stock[:w] * scale
    end

    layout_w = stock[:l] * scale
    origin_x = 0
    origin_y = pdf.cursor

    # Stock background
    pdf.fill_color STOCK_BG
    pdf.stroke_color STOCK_BORDER
    pdf.line_width 0.5
    pdf.fill_and_stroke_rectangle [origin_x, origin_y], layout_w, layout_h

    # Pieces
    (sheet["placements"] || []).each do |p|
      px = p["x"].to_f * scale
      py = p["y"].to_f * scale
      pw = p["rect"]["w"].to_f * scale
      ph = p["rect"]["h"].to_f * scale

      key = normalize_key(p["rect"]["w"], p["rect"]["h"])
      color = @color_map[key] || "a0aec0"

      rect_x = origin_x + px
      rect_y = origin_y - py

      pdf.fill_color color
      pdf.fill_rectangle [rect_x, rect_y], pw, ph
      pdf.stroke_color PIECE_BORDER
      pdf.line_width 0.3
      pdf.stroke_rectangle [rect_x, rect_y], pw, ph

      # Dimension label inside piece
      label = "#{p["rect"]["w"]}×#{p["rect"]["h"]}"
      label += " R" if p["rotated"]
      font_size = fit_font_size(pw, ph, label)

      if font_size >= 4
        pdf.fill_color TEXT_COLOR
        pdf.text_box label,
          at: [rect_x + 1, rect_y - 1],
          width: pw - 2,
          height: ph - 2,
          align: :center,
          valign: :center,
          size: font_size,
          overflow: :shrink_to_fit,
          min_font_size: 3
      end
    end

    # Dimension labels outside the sheet
    pdf.fill_color MUTED_COLOR
    # Length label (bottom center)
    pdf.text_box "#{stock[:l].to_i}",
      at: [origin_x, origin_y - layout_h - 3],
      width: layout_w,
      height: 10,
      align: :center,
      size: 7

    # Width label (right side, rotated)
    mid_y = origin_y - layout_h / 2
    pdf.rotate(90, origin: [origin_x + layout_w + 10, mid_y]) do
      pdf.text_box "#{stock[:w].to_i}",
        at: [origin_x + layout_w + 10 - 20, mid_y + 5],
        width: 40,
        height: 10,
        align: :center,
        size: 7
    end

    pdf.fill_color TEXT_COLOR
    pdf.move_cursor_to(origin_y - layout_h - 14)
  end

  # ── Footer ─────────────────────────────────────────────────────

  def draw_footer(pdf)
    pdf.number_pages "Page <page>/<total>",
      at: [pdf.bounds.width - 80, -10],
      size: 7,
      color: MUTED_COLOR

    pdf.number_pages I18n.l(Time.current, format: :short),
      at: [0, -10],
      size: 7,
      color: MUTED_COLOR
  end

  # ── Helpers ────────────────────────────────────────────────────

  def stock
    @stock ||= {
      l: @result.dig("stock", "w").to_f,
      w: @result.dig("stock", "h").to_f
    }
  end

  def sheets
    @result["sheets"] || []
  end

  def normalize_key(l, w)
    "#{[l, w].min}×#{[l, w].max}"
  end

  def build_color_map
    keys = Set.new
    sheets.each do |s|
      (s["placements"] || []).each do |p|
        keys.add(normalize_key(p["rect"]["w"], p["rect"]["h"]))
      end
    end
    map = {}
    keys.each_with_index { |k, i| map[k] = COLORS[i % COLORS.length] }
    map
  end

  def build_piece_summary
    counts = Hash.new(0)
    sheets.each do |s|
      (s["placements"] || []).each do |p|
        counts[normalize_key(p["rect"]["w"], p["rect"]["h"])] += 1
      end
    end
    counts
  end

  def draw_info_table(pdf, rows)
    pdf.font_size(INFO_FONT) do
      rows.each do |label, value|
        pdf.text "<b>#{label}</b>  #{value}", inline_format: true
        pdf.move_down 1
      end
    end
  end

  def make_cell(text, style = nil)
    h = { content: text }
    h[:font_style] = style if style
    h
  end

  def fit_font_size(pw, ph, label)
    char_w = label.length * 0.55
    max_by_width = pw / char_w
    max_by_height = ph / 1.2
    [[max_by_width, max_by_height, [pw, ph].min * 0.25].min, 4].max
  end
end
