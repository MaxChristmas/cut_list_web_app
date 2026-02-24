class LabelPdfService
  include PdfFontSetup

  FORMATS = {
    "65" => { name: "65", cols: 5, rows: 13, label_w: 38.1, label_h: 21.2, margin_top: 10.7, margin_left: 4.7, gap_x: 0, gap_y: 0 },
    "40" => { name: "40", cols: 4, rows: 10, label_w: 52.5, label_h: 29.7, margin_top: 13.5, margin_left: 0, gap_x: 0, gap_y: 0 },
    "24" => { name: "24", cols: 3, rows: 8, label_w: 64, label_h: 33.9, margin_top: 12.9, margin_left: 7.2, gap_x: 2.5, gap_y: 0 },
    "14" => { name: "14", cols: 2, rows: 7, label_w: 99.1, label_h: 38.1, margin_top: 15.2, margin_left: 4.7, gap_x: 2.5, gap_y: 0 },
    "10" => { name: "10", cols: 2, rows: 5, label_w: 99.1, label_h: 57, margin_top: 13, margin_left: 4.7, gap_x: 2.5, gap_y: 0 },
    "8"  => { name: "8",  cols: 2, rows: 4, label_w: 99.1, label_h: 67.7, margin_top: 13, margin_left: 4.7, gap_x: 2.5, gap_y: 0 }
  }.freeze

  TEXT_COLOR = "1a202c"
  MUTED_COLOR = "718096"
  BORDER_COLOR = "d0d0d0"

  # entries: array of { result: Hash, project_name: String }
  def initialize(entries, label_format)
    @entries = entries
    @format = FORMATS[label_format] || FORMATS["24"]
    @multi = entries.size > 1
  end

  def generate
    labels = build_labels
    fmt = @format

    Prawn::Document.new(page_size: "A4", margin: [0, 0, 0, 0]) do |pdf|
      setup_fonts(pdf)
      label_w = mm(fmt[:label_w])
      label_h = mm(fmt[:label_h])
      margin_top = mm(fmt[:margin_top])
      margin_left = mm(fmt[:margin_left])
      gap_x = mm(fmt[:gap_x])
      gap_y = mm(fmt[:gap_y])
      per_page = fmt[:cols] * fmt[:rows]

      labels.each_slice(per_page).with_index do |page_labels, page_idx|
        pdf.start_new_page unless page_idx.zero?

        page_labels.each_with_index do |label, idx|
          col = idx % fmt[:cols]
          row = idx / fmt[:cols]

          x = margin_left + col * (label_w + gap_x)
          y = pdf.bounds.height - margin_top - row * (label_h + gap_y)

          # Border (light dashed for cutting guide)
          pdf.stroke_color BORDER_COLOR
          pdf.line_width 0.25
          pdf.dash(2, space: 2)
          pdf.stroke_rectangle [x, y], label_w, label_h
          pdf.undash

          # Content centered in label
          padding = 4
          inner_w = label_w - padding * 2
          inner_h = label_h - padding * 2
          cx = x + padding
          cy = y - padding

          pdf.fill_color TEXT_COLOR

          if label_h >= mm(50)
            draw_large_label(pdf, label, cx, cy, inner_w, inner_h)
          elsif label_h >= mm(30)
            draw_medium_label(pdf, label, cx, cy, inner_w, inner_h)
          else
            draw_small_label(pdf, label, cx, cy, inner_w, inner_h)
          end
        end
      end
    end
  end

  private

  # Large labels (≥50mm height): each info on its own line, bold, big
  def draw_large_label(pdf, label, cx, cy, w, h)
    lines = build_lines(label)
    row_h = h / lines.size.to_f

    lines.each_with_index do |line, i|
      pdf.text_box line,
        at: [cx, cy - row_h * i], width: w, height: row_h,
        align: :center, valign: :center,
        size: 14, style: :bold,
        overflow: :shrink_to_fit, min_font_size: 7
    end
  end

  # Medium labels (30-50mm height): each info on its own line, bold
  def draw_medium_label(pdf, label, cx, cy, w, h)
    lines = build_lines(label)
    row_h = h / lines.size.to_f

    lines.each_with_index do |line, i|
      pdf.text_box line,
        at: [cx, cy - row_h * i], width: w, height: row_h,
        align: :center, valign: :center,
        size: 11, style: :bold,
        overflow: :shrink_to_fit, min_font_size: 5
    end
  end

  # Small labels (<30mm height): each info on its own line, bold
  def draw_small_label(pdf, label, cx, cy, w, h)
    lines = build_lines(label)
    row_h = h / lines.size.to_f

    lines.each_with_index do |line, i|
      pdf.text_box line,
        at: [cx, cy - row_h * i], width: w, height: row_h,
        align: :center, valign: :center,
        size: 8, style: :bold,
        overflow: :shrink_to_fit, min_font_size: 3
    end
  end

  def build_lines(label)
    lines = []
    lines << label[:project_name] if @multi && label[:project_name].present?
    lines << label[:label] if label[:label].present?
    lines << I18n.t("labels.dimension", length: label[:length], width: label[:width])
    lines << "#{label[:index]} / #{label[:total]}"
    lines << I18n.t("labels.total", count: label[:total])
    lines
  end

  # Build one label per individual piece (qty 4 = 4 labels)
  def build_labels
    labels = []

    @entries.each do |entry|
      result = entry[:result]
      project_name = entry[:project_name]
      pieces = result["pieces"] || []

      pieces.each do |p|
        l = (p["length"] || p["l"]).to_f
        w = (p["width"] || p["w"]).to_f
        qty = (p["quantity"] || p["qty"] || 1).to_i
        piece_label = p["label"].presence

        qty.times do |i|
          labels << {
            length: format_dim(l),
            width: format_dim(w),
            label: piece_label,
            index: i + 1,
            total: qty,
            project_name: project_name
          }
        end
      end
    end

    labels
  end

  def format_dim(n)
    n == n.to_i ? n.to_i.to_s : n.to_s
  end

  def mm(val)
    val * 72.0 / 25.4
  end
end
