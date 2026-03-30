class CutListDxfService
  # DXF ASCII format — no external gem required.
  # Each sheet is placed on its own layer (SHEET_1, SHEET_2, …).
  # Stock outline → LWPOLYLINE on the layer.
  # Each piece placement → LWPOLYLINE on the same layer.
  # Piece dimensions + label → TEXT entities.

  def initialize(result, project)
    @result = result
    @project = project
  end

  def generate
    lines = []
    lines << header_section
    lines << tables_section
    lines << entities_section
    lines << "0\nEOF\n"
    lines.join
  end

  private

  # ── Data helpers (mirrored from CutListPdfService) ──────────────

  def stock
    @stock ||= {
      w: (@result.dig("stock", "w") || @result.dig("stock", "length")).to_f,
      h: (@result.dig("stock", "h") || @result.dig("stock", "width")).to_f
    }
  end

  def sheets
    @result["sheets"] || []
  end

  def piece_dims(rect)
    w = (rect["w"] || rect["length"]).to_f
    h = (rect["h"] || rect["width"]).to_f
    [ w, h ]
  end

  def normalize_key(w, h)
    "#{fmt([ w, h ].max)}×#{fmt([ w, h ].min)}"
  end

  def fmt(n)
    n == n.to_i ? n.to_i.to_s : n.to_s
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

  # ── DXF sections ────────────────────────────────────────────────

  def header_section
    <<~DXF
      0
      SECTION
      2
      HEADER
      9
      $ACADVER
      1
      AC1015
      9
      $INSUNITS
      70
      4
      0
      ENDSEC
    DXF
  end

  def tables_section
    out = "0\nSECTION\n2\nTABLES\n"
    out << ltype_table
    out << layer_table
    out << "0\nENDSEC\n"
    out
  end

  def ltype_table
    <<~DXF
      0
      TABLE
      2
      LTYPE
      70
      1
      0
      LTYPE
      2
      CONTINUOUS
      70
      0
      3
      Solid line
      72
      65
      73
      0
      40
      0.0
      0
      ENDTAB
    DXF
  end

  def layer_table
    out = "0\nTABLE\n2\nLAYER\n70\n#{sheets.size + 1}\n"

    # Layer 0 is mandatory per DXF spec
    out << layer_entry("0", 7)

    sheets.each_with_index do |_sheet, i|
      out << layer_entry("SHEET_#{i + 1}", layer_color(i))
    end

    out << "0\nENDTAB\n"
    out
  end

  def layer_entry(name, color)
    <<~DXF
      0
      LAYER
      2
      #{name}
      70
      0
      62
      #{color}
      6
      CONTINUOUS
    DXF
  end

  # ACI color index cycling through a distinct set of colors
  LAYER_COLORS = [ 1, 2, 3, 4, 5, 6, 30, 40, 50, 170 ].freeze

  def layer_color(index)
    LAYER_COLORS[index % LAYER_COLORS.size]
  end

  def entities_section
    label_map = build_label_map
    out = "0\nSECTION\n2\nENTITIES\n"

    sw = stock[:w]
    sh = stock[:h]

    sheets.each_with_index do |sheet, i|
      layer = "SHEET_#{i + 1}"

      # Stock rectangle
      out << lwpolyline(0, 0, sw, sh, layer, color: 8)

      # Piece placements
      (sheet["placements"] || []).each do |p|
        pw, ph = piece_dims(p["rect"])
        px = p["x"].to_f
        py = p["y"].to_f

        out << lwpolyline(px, py, pw, ph, layer, color: layer_color(i))

        # Label text centred in the piece (if present)
        key = normalize_key(pw, ph)
        if label_map[key]
          cx = px + pw / 2.0
          cy = py + ph / 2.0
          text_height = [ pw, ph ].min * 0.08
          text_height = 5.0 if text_height < 5
          out << text_entity(cx, cy, label_map[key], text_height, layer)
        end
      end

      # Offset successive sheets horizontally so they do not overlap
      # (each sheet starts at x = index * (stock_width + gap))
    end

    out << "0\nENDSEC\n"
    out
  end

  # Closed LWPOLYLINE for a rectangle at (x, y) with size (w, h).
  # DXF y-axis: bottom-left origin. The input y is a top-left origin
  # (same as the optimizer's coordinate space, where y increases downward).
  # We flip to DXF space: dxf_y = sheet_height - y - piece_height.
  def lwpolyline(x, y, w, h, layer, color: 256)
    sh = stock[:h]
    # Convert top-left origin to bottom-left DXF origin
    dxf_y = sh - y - h

    x0 = x.round(4)
    y0 = dxf_y.round(4)
    x1 = (x + w).round(4)
    y1 = (dxf_y + h).round(4)

    <<~DXF
      0
      LWPOLYLINE
      8
      #{layer}
      62
      #{color}
      90
      4
      70
      1
      10
      #{x0}
      20
      #{y0}
      10
      #{x1}
      20
      #{y0}
      10
      #{x1}
      20
      #{y1}
      10
      #{x0}
      20
      #{y1}
    DXF
  end

  def text_entity(cx, cy, content, height, layer)
    sh = stock[:h]
    # cx/cy are already in top-left origin space for text centre; convert to DXF
    dxf_y = sh - cy

    <<~DXF
      0
      TEXT
      8
      #{layer}
      10
      #{cx.round(4)}
      20
      #{dxf_y.round(4)}
      30
      0.0
      40
      #{height.round(4)}
      1
      #{content}
      72
      1
      11
      #{cx.round(4)}
      21
      #{dxf_y.round(4)}
    DXF
  end
end
