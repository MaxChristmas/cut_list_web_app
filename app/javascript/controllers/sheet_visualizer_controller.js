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

    // Optimizer convention: length = x-axis, width = y-axis
    const stock = { w: data.stock.w ?? data.stock.length, h: data.stock.h ?? data.stock.width }
    const maxWidth = 700
    const scale = maxWidth / stock.w
    const colorMap = this.buildColorMap(data.sheets)
    const labelMap = this.buildLabelMap(data.pieces || [])

    const container = this.element
    container.innerHTML = ""

    data.sheets.forEach((sheet, i) => {
      const heading = document.createElement("h3")
      heading.className = "text-md font-semibold mt-6 mb-2"
      const wastePercent = ((sheet.waste_area / (stock.w * stock.h)) * 100).toFixed(1)
      heading.textContent = `Sheet ${i + 1} — Waste: ${wastePercent}%`
      container.appendChild(heading)

      const labelMargin = stock.w * 0.06
      const svgW = stock.w + labelMargin * 2
      const svgHTotal = stock.h + labelMargin * 2
      const actualWidth = maxWidth + maxWidth * 0.12
      const actualHeight = svgHTotal * scale

      const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
      svg.setAttribute("width", actualWidth)
      svg.setAttribute("height", actualHeight)
      svg.setAttribute("viewBox", `${-labelMargin} ${-labelMargin} ${svgW} ${svgHTotal}`)
      svg.setAttribute("class", "rounded")

      // Stock background
      const bg = this.svgRect(0, 0, stock.w, stock.h, "#dce6f0", "#cbd5e0", 2)
      svg.appendChild(bg)

      // Dimension labels
      const dimFontSize = stock.w * 0.04

      // Width at top
      const topLabel = this.svgText(stock.w / 2, -labelMargin * 0.4, `${stock.w}`, dimFontSize)
      svg.appendChild(topLabel)

      // Width at bottom
      const bottomLabel = this.svgText(stock.w / 2, stock.h + labelMargin * 0.6, `${stock.w}`, dimFontSize)
      svg.appendChild(bottomLabel)

      // Length on left (vertical)
      const leftLabel = this.svgText(-labelMargin * 0.4, stock.h / 2, `${stock.h}`, dimFontSize)
      leftLabel.setAttribute("transform", `rotate(-90, ${-labelMargin * 0.4}, ${stock.h / 2})`)
      svg.appendChild(leftLabel)

      sheet.placements.forEach((p) => {
        const rw = p.rect.w ?? p.rect.length
        const rh = p.rect.h ?? p.rect.width
        const key = this.normalizeKey(rw, rh, p.rotated)
        const color = colorMap[key] || "#a0aec0"

        const pw = rw
        const ph = rh

        const rect = this.svgRect(p.x, p.y, pw, ph, color, "#0f1117", 1.5)
        rect.setAttribute("opacity", "0.8")
        svg.appendChild(rect)

        // Dimension labels on edges (like stock dimensions)
        const pFontSize = Math.min(Math.min(pw, ph) * 0.12, 70)
        const inset = pFontSize * 0.8

        // Width at top (horizontal)
        const topW = this.svgText(p.x + pw / 2, p.y + inset, `${pw}`, pFontSize)
        topW.setAttribute("class", "select-none pointer-events-none")
        topW.setAttribute("fill", "#1a202c")
        svg.appendChild(topW)

        // Length on left (vertical)
        const leftH = this.svgText(p.x + inset, p.y + ph / 2, `${ph}`, pFontSize)
        leftH.setAttribute("class", "select-none pointer-events-none")
        leftH.setAttribute("fill", "#1a202c")
        leftH.setAttribute("transform", `rotate(-90, ${p.x + inset}, ${p.y + ph / 2})`)
        svg.appendChild(leftH)

        // Label centered in piece
        const label = labelMap[key]
        if (label) {
          const labelFontSize = pFontSize
          const labelEl = this.svgText(p.x + pw / 2, p.y + ph / 2, label, labelFontSize)
          labelEl.setAttribute("class", "select-none pointer-events-none")
          labelEl.setAttribute("fill", "#4a5568")
          labelEl.setAttribute("font-weight", "400")
          svg.appendChild(labelEl)
        }
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

  buildLabelMap(pieces) {
    const map = {}
    pieces.forEach((p) => {
      if (!p.label) return
      const l = parseFloat(p.length) || parseFloat(p.l) || 0
      const w = parseFloat(p.width) || parseFloat(p.w) || 0
      const key = this.normalizeKey(l, w)
      if (!map[key]) map[key] = p.label
    })
    return map
  }

  buildColorMap(sheets) {
    const keys = new Set()
    sheets.forEach((s) => {
      s.placements.forEach((p) => {
        keys.add(this.normalizeKey(p.rect.w ?? p.rect.length, p.rect.h ?? p.rect.width))
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

  svgText(x, y, content, fontSize) {
    const text = document.createElementNS("http://www.w3.org/2000/svg", "text")
    text.setAttribute("x", x)
    text.setAttribute("y", y)
    text.setAttribute("text-anchor", "middle")
    text.setAttribute("dominant-baseline", "central")
    text.setAttribute("font-size", fontSize)
    text.setAttribute("font-family", "Arial, Helvetica, sans-serif")
    text.setAttribute("font-weight", "700")
    text.setAttribute("fill", "#1a202c")
    text.textContent = content
    return text
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
