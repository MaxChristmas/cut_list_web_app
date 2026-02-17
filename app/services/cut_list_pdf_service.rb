class CutListPdfService
  COLORS = %w[4299e1 48bb78 ed8936 9f7aea f56565 38b2ac ecc94b e53e9e 667eea dd6b20].freeze
  STOCK_BG = "f7fafc"
  STOCK_BORDER = "a0aec0"
  PIECE_BORDER = "2d3748"
  TEXT_COLOR = "1a202c"
  HEADER_COLOR = "1A6ACD"
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
      @label_map = build_label_map
      @display_key_map = build_display_key_map

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
        [t("total_area_used"), "#{used_pct}%"],
        [t("total_waste_area"), "#{waste_pct}%"],
        [t("total_pieces"), total_cuts.to_s],
        [t("blade_kerf"), (@result["kerf"] || 0).to_s + " mm"]
      ]
      draw_info_table(pdf, info_rows)
    end

    # Right: piece types + stock
    pdf.bounding_box([left_w, top], width: right_w) do
      pieces_text = @piece_summary.map { |k, q| "#{display_key(k)} (x#{q})" }.join("  ·  ")
      draw_info_table(pdf, [
        [t("pieces"), pieces_text],
        [t("stock_sheet"), "#{stock[:l].to_i}×#{stock[:w].to_i} (x#{sheets.size})"]
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
      available_h = top - 40
      pdf.bounding_box([right_x, top], width: right_w) do
        draw_sheet_layout(pdf, sheet, right_w, available_h)
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
    unique_pieces = placements.map { |p| w, h = piece_dims(p["rect"]); normalize_key(w, h) }.uniq.size

    pdf.fill_color HEADER_COLOR
    pdf.font_size(11) do
      pdf.text t("sheet", number: index + 1), style: :bold
    end
    pdf.fill_color TEXT_COLOR
    pdf.move_down 4

    rows = [
      [t("stock_sheet"), "#{stock[:l].to_i}×#{stock[:w].to_i}"],
      [t("area_used"), "#{used_pct}%"],
      [t("waste_area"), "#{waste_pct}%"],
      [t("pieces"), placements.size.to_s],
      [t("unique_sizes"), unique_pieces.to_s]
    ]
    draw_info_table(pdf, rows)
  end

  def draw_piece_table(pdf, sheet)
    placements = sheet["placements"] || []
    counts = Hash.new(0)
    placements.each { |p| w, h = piece_dims(p["rect"]); counts[normalize_key(w, h)] += 1 }

    return if counts.empty?

    sq = LABEL_FONT
    table_w = pdf.bounds.width * 0.85
    row_h = sq + 6

    pdf.font_size(LABEL_FONT) do
      # Header
      pdf.fill_color TEXT_COLOR
      pdf.text_box t("piece"), at: [sq + 6, pdf.cursor], width: table_w - 40, style: :bold, size: LABEL_FONT
      pdf.text_box t("qty"), at: [table_w - 30, pdf.cursor], width: 30, align: :right, style: :bold, size: LABEL_FONT
      pdf.move_down row_h
      pdf.stroke_color "cccccc"
      pdf.line_width 0.5
      pdf.stroke_horizontal_line 0, table_w
      pdf.move_down 3

      # Data rows
      counts.each do |k, q|
        color = @color_map[k] || "a0aec0"
        y = pdf.cursor

        # Color swatch
        pdf.fill_color color
        pdf.fill_rectangle [0, y], sq, sq
        pdf.stroke_color PIECE_BORDER
        pdf.line_width 0.3
        pdf.stroke_rectangle [0, y], sq, sq

        # Piece name and qty
        pdf.fill_color TEXT_COLOR
        piece_label = @label_map[k]
        dk = display_key(k)
        piece_text = piece_label ? "#{dk} — #{piece_label}" : dk
        pdf.text_box piece_text, at: [sq + 6, y], width: table_w - sq - 36, size: LABEL_FONT
        pdf.text_box q.to_s, at: [table_w - 30, y], width: 30, align: :right, size: LABEL_FONT
        pdf.move_down row_h
      end
    end
    pdf.fill_color TEXT_COLOR
  end

  # ── Sheet visual layout ────────────────────────────────────────

  def draw_sheet_layout(pdf, sheet, available_w, available_h)
    portrait = stock[:l] > stock[:w]

    if portrait
      draw_stock_w = stock[:w]
      draw_stock_h = stock[:l]
    else
      draw_stock_w = stock[:l]
      draw_stock_h = stock[:w]
    end

    scale_w = available_w / draw_stock_w.to_f
    scale_h = available_h > 0 ? available_h / draw_stock_h.to_f : scale_w
    scale = [scale_w, scale_h].min

    layout_w = draw_stock_w * scale
    layout_h = draw_stock_h * scale
    origin_x = 0
    origin_y = pdf.cursor

    # Stock background
    pdf.fill_color STOCK_BG
    pdf.stroke_color STOCK_BORDER
    pdf.line_width 0.5
    pdf.fill_and_stroke_rectangle [origin_x, origin_y], layout_w, layout_h

    # Pieces
    (sheet["placements"] || []).each do |p|
      rw, rh = piece_dims(p["rect"])

      if portrait
        px = p["y"].to_f * scale
        py = p["x"].to_f * scale
        pw = rh * scale
        ph = rw * scale
      else
        px = p["x"].to_f * scale
        py = p["y"].to_f * scale
        pw = rw * scale
        ph = rh * scale
      end

      key = normalize_key(rw, rh)
      color = @color_map[key] || "a0aec0"

      rect_x = origin_x + px
      rect_y = origin_y - py

      pdf.fill_color color
      pdf.fill_rectangle [rect_x, rect_y], pw, ph
      pdf.stroke_color PIECE_BORDER
      pdf.line_width 0.3
      pdf.stroke_rectangle [rect_x, rect_y], pw, ph

      # Dimension labels on corresponding sides
      h_dim = portrait ? rh : rw  # horizontal real dimension
      v_dim = portrait ? rw : rh  # vertical real dimension
      dim_font = [[pw * 0.18, ph * 0.28, 7].min, 2].max
      pdf.fill_color TEXT_COLOR

      # Bottom label (horizontal dimension)
      pdf.text_box fmt(h_dim),
        at: [rect_x + 1, rect_y - ph + dim_font + 1],
        width: pw - 2,
        height: dim_font + 2,
        align: :center,
        size: dim_font,
        overflow: :shrink_to_fit,
        min_font_size: 2

      # Right side label (vertical dimension, rotated)
      mid_x = rect_x + pw - dim_font / 2 - 1
      mid_y = rect_y - ph / 2
      pdf.rotate(90, origin: [mid_x, mid_y]) do
        pdf.text_box fmt(v_dim),
          at: [mid_x - (ph - 2) / 2, mid_y + (dim_font + 2) / 2],
          width: ph - 2,
          height: dim_font + 2,
          align: :center,
          size: dim_font,
          overflow: :shrink_to_fit,
          min_font_size: 2
      end

      # Piece label centered, oriented along the length direction
      label = @label_map[key]
      if label
        original_l = @original_length_map[key] || [rw, rh].max
        length_is_vertical = portrait ? (rw - original_l).abs < 0.01 : (rh - original_l).abs < 0.01

        if length_is_vertical
          label_font = [[ph * 0.22, pw * 0.22, 8].min, 3].max
          mid_x = rect_x + pw / 2
          mid_y = rect_y - ph / 2
          pdf.fill_color TEXT_COLOR
          pdf.rotate(90, origin: [mid_x, mid_y]) do
            pdf.text_box label,
              at: [mid_x - (ph - 2) / 2, mid_y + (label_font + 2) / 2],
              width: ph - 2,
              height: label_font + 2,
              align: :center,
              size: label_font,
              overflow: :shrink_to_fit,
              min_font_size: 2,
              style: :bold
          end
        else
          label_font = [[pw * 0.22, ph * 0.22, 8].min, 3].max
          pdf.fill_color TEXT_COLOR
          pdf.text_box label,
            at: [rect_x + 1, rect_y - ph / 2 + label_font / 2 + 1],
            width: pw - 2,
            height: label_font + 2,
            align: :center,
            size: label_font,
            overflow: :shrink_to_fit,
            min_font_size: 2,
            style: :bold
        end
      end
    end

    # Dimension labels outside the sheet
    pdf.fill_color MUTED_COLOR
    # Bottom label (horizontal dimension)
    pdf.text_box "#{draw_stock_w.to_i}",
      at: [origin_x, origin_y - layout_h - 3],
      width: layout_w,
      height: 10,
      align: :center,
      size: 7

    # Right side label (vertical dimension, rotated)
    mid_y = origin_y - layout_h / 2
    pdf.rotate(90, origin: [origin_x + layout_w + 10, mid_y]) do
      pdf.text_box "#{draw_stock_h.to_i}",
        at: [origin_x + layout_w + 10 - 20, mid_y + 5],
        width: 40,
        height: 10,
        align: :center,
        size: 7
    end

    pdf.move_cursor_to(origin_y - layout_h - 14)
  end

  # ── Footer ─────────────────────────────────────────────────────

  def draw_footer(pdf)
    locale_suffix = I18n.locale == :ja ? "jp" : I18n.locale.to_s
    logo_path = Rails.root.join("app/assets/images/cutoptima-logo-#{locale_suffix}.svg")
    logo_h = 19
    logo_w = logo_h * (400.0 / 120)
    footer_y = -30 + logo_h + 5

    pdf.repeat(:all) do
      pdf.svg File.read(logo_path), at: [0, footer_y], width: logo_w, height: logo_h
    end

    pdf.number_pages I18n.l(Time.current, format: :short),
      at: [0, footer_y - (logo_h - 7) / 2],
      width: pdf.bounds.width,
      size: 7,
      align: :center,
      color: MUTED_COLOR

    pdf.number_pages "Page <page>/<total>",
      at: [pdf.bounds.width - 80, footer_y - (logo_h - 7) / 2],
      size: 7,
      color: MUTED_COLOR
  end

  # ── Helpers ────────────────────────────────────────────────────

  def stock
    @stock ||= {
      l: (@result.dig("stock", "w") || @result.dig("stock", "length")).to_f,
      w: (@result.dig("stock", "h") || @result.dig("stock", "width")).to_f
    }
  end

  def sheets
    @result["sheets"] || []
  end

  def piece_dims(rect)
    w = (rect["w"] || rect["length"]).to_f
    h = (rect["h"] || rect["width"]).to_f
    [w, h]
  end

  def normalize_key(l, w)
    "#{fmt([l, w].max)}×#{fmt([l, w].min)}"
  end

  def fmt(n)
    n == n.to_i ? n.to_i.to_s : n.to_s
  end

  def build_color_map
    keys = Set.new
    sheets.each do |s|
      (s["placements"] || []).each do |p|
        w, h = piece_dims(p["rect"])
        keys.add(normalize_key(w, h))
      end
    end
    map = {}
    keys.each_with_index { |k, i| map[k] = COLORS[i % COLORS.length] }
    map
  end

  def build_label_map
    map = {}
    (@result["pieces"] || []).each do |p|
      next unless p["label"].present?
      l = (p["length"] || p["l"]).to_f
      w = (p["width"] || p["w"]).to_f
      key = normalize_key(l, w)
      map[key] ||= p["label"]
    end
    map
  end

  def build_display_key_map
    map = {}
    @original_length_map = {}
    (@result["pieces"] || []).each do |p|
      l = (p["length"] || p["l"]).to_f
      w = (p["width"] || p["w"]).to_f
      key = normalize_key(l, w)
      map[key] ||= "#{fmt(l)}×#{fmt(w)}"
      @original_length_map[key] ||= l
    end
    map
  end

  def display_key(k)
    @display_key_map[k] || k
  end

  def build_piece_summary
    counts = Hash.new(0)
    sheets.each do |s|
      (s["placements"] || []).each do |p|
        w, h = piece_dims(p["rect"])
        counts[normalize_key(w, h)] += 1
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
