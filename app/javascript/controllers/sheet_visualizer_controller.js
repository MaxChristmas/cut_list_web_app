import { Controller } from "@hotwired/stimulus"

const COLORS = [
  "#4299e1", "#48bb78", "#ed8936", "#9f7aea",
  "#f56565", "#38b2ac", "#ecc94b", "#e53e9e",
  "#667eea", "#dd6b20",
]

export default class extends Controller {
  static values = { result: Object }

  connect() {
    this.render()
  }

  render() {
    const data = this.resultValue
    if (!data || !data.sheets) return

    const stock = data.stock
    const maxWidth = 700
    const scale = maxWidth / stock.w
    const svgH = stock.h * scale

    const colorMap = this.buildColorMap(data.sheets)

    const container = this.element
    container.innerHTML = ""

    data.sheets.forEach((sheet, i) => {
      const heading = document.createElement("h3")
      heading.className = "text-md font-semibold mt-6 mb-2"
      const wastePercent = ((sheet.waste_area / (stock.w * stock.h)) * 100).toFixed(1)
      heading.textContent = `Sheet ${i + 1} — Waste: ${wastePercent}%`
      container.appendChild(heading)

      const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
      svg.setAttribute("width", maxWidth)
      svg.setAttribute("height", svgH)
      svg.setAttribute("viewBox", `0 0 ${stock.w} ${stock.h}`)
      svg.setAttribute("class", "border border-gray-300 rounded bg-white")

      // Stock background
      const bg = this.svgRect(0, 0, stock.w, stock.h, "#f7fafc", "#cbd5e0", 2)
      svg.appendChild(bg)

      sheet.placements.forEach((p) => {
        const key = this.normalizeKey(p.rect.w, p.rect.h, p.rotated)
        const color = colorMap[key] || "#a0aec0"

        // rect.w and rect.h are already the placed dimensions
        const pw = p.rect.w
        const ph = p.rect.h

        const rect = this.svgRect(p.x, p.y, pw, ph, color, "#2d3748", 1)
        rect.setAttribute("opacity", "0.8")
        svg.appendChild(rect)

        // Dimension label
        const label = document.createElementNS("http://www.w3.org/2000/svg", "text")
        label.setAttribute("x", p.x + pw / 2)
        label.setAttribute("y", p.y + ph / 2)
        label.setAttribute("text-anchor", "middle")
        label.setAttribute("dominant-baseline", "central")
        label.setAttribute("class", "select-none pointer-events-none")

        const fontSize = this.fitFontSize(pw, ph, p.rect.w, p.rect.h, p.rotated)
        label.setAttribute("font-size", fontSize)
        label.setAttribute("fill", "#1a202c")
        label.setAttribute("font-weight", "600")

        let text = `${p.rect.w}×${p.rect.h}`
        if (p.rotated) text += " R"
        label.textContent = text
        svg.appendChild(label)
      })

      container.appendChild(svg)
    })

    // Summary
    const summary = document.createElement("p")
    summary.className = "mt-4 text-sm text-gray-600"
    summary.textContent = `${data.sheet_count} sheet(s) — Overall waste: ${data.waste_percent}%`
    container.appendChild(summary)
  }

  normalizeKey(w, h, _rotated) {
    return `${Math.min(w, h)}×${Math.max(w, h)}`
  }

  buildColorMap(sheets) {
    const keys = new Set()
    sheets.forEach((s) => {
      s.placements.forEach((p) => {
        keys.add(this.normalizeKey(p.rect.w, p.rect.h))
      })
    })
    const map = {}
    let i = 0
    keys.forEach((k) => {
      map[k] = COLORS[i % COLORS.length]
      i++
    })
    return map
  }

  fitFontSize(pw, ph, origW, origH, rotated) {
    const minDim = Math.min(pw, ph)
    const label = `${origW}×${origH}${rotated ? " R" : ""}`
    const charW = label.length * 0.6
    const maxByWidth = pw / charW
    const maxByHeight = ph / 1.2
    return Math.max(10, Math.min(maxByWidth, maxByHeight, minDim * 0.25))
  }

  svgRect(x, y, w, h, fill, stroke, strokeWidth) {
    const rect = document.createElementNS("http://www.w3.org/2000/svg", "rect")
    rect.setAttribute("x", x)
    rect.setAttribute("y", y)
    rect.setAttribute("width", w)
    rect.setAttribute("height", h)
    rect.setAttribute("fill", fill)
    rect.setAttribute("stroke", stroke)
    rect.setAttribute("stroke-width", strokeWidth)
    return rect
  }
}
