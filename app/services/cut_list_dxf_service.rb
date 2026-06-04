class CutListDxfService
  # Minimal DXF format: ENTITIES section only, no HEADER, no TABLES.
  # Modelled after DXF files that Fusion 360 Personal successfully imports.
  # Each sheet on its own named layer; 4 LINE entities per rectangle.

  def initialize(result, project)
    @result = result
    @project = project
  end

  def generate
    out = "0\nSECTION\n2\nENTITIES\n"
    out << entity_lines
    out << "0\nENDSEC\n0\nEOF\n"
    out
  end

  private

  # ── Data helpers ────────────────────────────────────────────────

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

  # ── Entity generation ────────────────────────────────────────────

  def entity_lines
    label_map = build_label_map
    out = ""
    sw = stock[:w]
    sh = stock[:h]

    sheets.each_with_index do |sheet, i|
      layer = "SHEET_#{i + 1}"

      out << rect_lines(0, 0, sw, sh, layer, color: 8)

      (sheet["placements"] || []).each do |p|
        pw, ph = piece_dims(p["rect"])
        px = p["x"].to_f
        py = p["y"].to_f

        out << rect_lines(px, py, pw, ph, layer, color: layer_color(i))

        key = normalize_key(pw, ph)
        if label_map[key]
          cx = px + pw / 2.0
          cy = py + ph / 2.0
          text_height = [ pw, ph ].min * 0.08
          text_height = 5.0 if text_height < 5
          out << text_entity(cx, cy, label_map[key], text_height, layer)
        end
      end
    end

    out
  end

  # 4 LINE entities forming a closed rectangle.
  # Converts top-left origin (optimizer space) to DXF bottom-left origin.
  def rect_lines(x, y, w, h, layer, color: 256)
    sh = stock[:h]
    dxf_y = sh - y - h

    x0 = x.to_f.round(4)
    y0 = dxf_y.to_f.round(4)
    x1 = (x.to_f + w).round(4)
    y1 = (dxf_y + h).round(4)

    [
      [x0, y0, x1, y0],  # bottom
      [x1, y0, x1, y1],  # right
      [x1, y1, x0, y1],  # top
      [x0, y1, x0, y0]   # left
    ].map do |sx0, sy0, sx1, sy1|
      "0\nLINE\n8\n#{layer}\n62\n#{color}\n" \
        "10\n#{sx0}\n20\n#{sy0}\n30\n0.0\n" \
        "11\n#{sx1}\n21\n#{sy1}\n31\n0.0\n"
    end.join
  end

  def text_entity(cx, cy, content, height, layer)
    sh = stock[:h]
    dxf_y = sh - cy
    "0\nTEXT\n8\n#{layer}\n" \
      "10\n#{cx.round(4)}\n20\n#{dxf_y.round(4)}\n30\n0.0\n40\n#{height.round(4)}\n" \
      "1\n#{content}\n72\n1\n11\n#{cx.round(4)}\n21\n#{dxf_y.round(4)}\n"
  end

  LAYER_COLORS = [ 1, 2, 3, 4, 5, 6, 30, 40, 50, 170 ].freeze

  def layer_color(index)
    LAYER_COLORS[index % LAYER_COLORS.size]
  end
end
