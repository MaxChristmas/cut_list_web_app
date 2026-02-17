import { Controller } from "@hotwired/stimulus"

const COLORS = [
  "#4299e1", "#48bb78", "#ed8936", "#9f7aea",
  "#f56565", "#38b2ac", "#ecc94b", "#e53e9e",
  "#667eea", "#dd6b20",
]

export default class extends Controller {
  static targets = ["toolbar", "canvas"]
  static values = {
    result: Object,
    editedResult: Object,
    saveUrl: String,
    resetUrl: String,
    editLabel: String,
    editingLabel: String,
    saveLabel: String,
    resetLabel: String,
    sheetHeadingTemplate: String,
    summaryTemplate: String,
    readonly: { type: Boolean, default: false },
  }

  connect() {
    this.editMode = false
    this.dragging = null
    this.workingData = null
    this.render()
  }

  getDisplayData() {
    if (this.workingData) return this.workingData
    const edited = this.editedResultValue
    if (edited && edited.sheets) return edited
    return this.resultValue
  }

  toggleEditMode() {
    this.editMode = !this.editMode
    if (this.editMode && !this.workingData) {
      this.workingData = JSON.parse(JSON.stringify(this.getDisplayData()))
    }
    if (!this.editMode) {
      this.workingData = null
    }
    this.render()
  }

  async saveLayout() {
    if (!this.workingData) return

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    const response = await fetch(this.saveUrlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
      },
      body: JSON.stringify(this.workingData),
    })

    if (response.ok) {
      this.editedResultValue = this.workingData
      this.editMode = false
      this.workingData = null
      this.render()
    }
  }

  resetLayout() {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    const form = document.createElement("form")
    form.method = "POST"
    form.action = this.resetUrlValue

    const methodInput = document.createElement("input")
    methodInput.type = "hidden"
    methodInput.name = "_method"
    methodInput.value = "patch"
    form.appendChild(methodInput)

    const tokenInput = document.createElement("input")
    tokenInput.type = "hidden"
    tokenInput.name = "authenticity_token"
    tokenInput.value = csrfToken
    form.appendChild(tokenInput)

    document.body.appendChild(form)
    form.submit()
  }

  render() {
    const data = this.getDisplayData()
    if (!data || !data.sheets) return

    const stock = { w: data.stock.w ?? data.stock.length, h: data.stock.h ?? data.stock.width }
    const maxWidth = 700
    const scale = maxWidth / stock.w
    const colorMap = this.buildColorMap(data.sheets)
    const labelMap = this.buildLabelMap(data.pieces || [])

    const container = this.hasCanvasTarget ? this.canvasTarget : this.element
    container.innerHTML = ""

    // Toolbar
    this.renderToolbar(container)

    data.sheets.forEach((sheet, i) => {
      const heading = document.createElement("h3")
      heading.className = "text-md font-semibold mt-6 mb-2"
      const wastePercent = ((sheet.waste_area / (stock.w * stock.h)) * 100).toFixed(1)
      const headingTpl = this.sheetHeadingTemplateValue || "Sheet %{number} — Waste: %{waste}%"
      heading.textContent = headingTpl.replace("%{number}", i + 1).replace("%{waste}", wastePercent)
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

      if (this.editMode) {
        svg.style.cursor = "default"
        svg.addEventListener("pointermove", (e) => this.onPointerMove(e, svg))
        svg.addEventListener("pointerup", () => this.onPointerUp())
        svg.addEventListener("pointerleave", () => this.onPointerUp())
      }

      // Stock background
      const bg = this.svgRect(0, 0, stock.w, stock.h, "#dce6f0", this.editMode ? "#3b82f6" : "#cbd5e0", this.editMode ? 3 : 2)
      svg.appendChild(bg)

      // Dimension labels
      const dimFontSize = stock.w * 0.04

      const topLabel = this.svgText(stock.w / 2, -labelMargin * 0.4, `${stock.w}`, dimFontSize)
      svg.appendChild(topLabel)

      const bottomLabel = this.svgText(stock.w / 2, stock.h + labelMargin * 0.6, `${stock.w}`, dimFontSize)
      svg.appendChild(bottomLabel)

      const leftLabel = this.svgText(-labelMargin * 0.4, stock.h / 2, `${stock.h}`, dimFontSize)
      leftLabel.setAttribute("transform", `rotate(-90, ${-labelMargin * 0.4}, ${stock.h / 2})`)
      svg.appendChild(leftLabel)

      sheet.placements.forEach((p, pi) => {
        const rw = p.rect.w ?? p.rect.length
        const rh = p.rect.h ?? p.rect.width
        const key = this.normalizeKey(rw, rh, p.rotated)
        const color = colorMap[key] || "#a0aec0"

        const pw = rw
        const ph = rh

        if (this.editMode) {
          const group = document.createElementNS("http://www.w3.org/2000/svg", "g")
          group.setAttribute("transform", `translate(${p.x}, ${p.y})`)
          group.style.cursor = "grab"
          group.dataset.sheetIndex = i
          group.dataset.placementIndex = pi

          const rect = this.svgRect(0, 0, pw, ph, color, "#0f1117", 1.5)
          rect.setAttribute("opacity", "0.8")
          group.appendChild(rect)

          // Piece dimension labels
          const pFontSize = Math.min(Math.min(pw, ph) * 0.12, 70)
          const inset = pFontSize * 0.8

          const topW = this.svgText(pw / 2, inset, `${pw}`, pFontSize)
          topW.setAttribute("class", "select-none pointer-events-none")
          topW.setAttribute("fill", "#1a202c")
          group.appendChild(topW)

          const leftH = this.svgText(inset, ph / 2, `${ph}`, pFontSize)
          leftH.setAttribute("class", "select-none pointer-events-none")
          leftH.setAttribute("fill", "#1a202c")
          leftH.setAttribute("transform", `rotate(-90, ${inset}, ${ph / 2})`)
          group.appendChild(leftH)

          const label = labelMap[key]
          if (label) {
            const labelFontSize = pFontSize
            const labelEl = this.svgText(pw / 2, ph / 2, label, labelFontSize)
            labelEl.setAttribute("class", "select-none pointer-events-none")
            labelEl.setAttribute("fill", "#4a5568")
            labelEl.setAttribute("font-weight", "400")
            group.appendChild(labelEl)
          }

          group.addEventListener("pointerdown", (e) => this.onPointerDown(e, group, svg, i, pi))

          svg.appendChild(group)
        } else {
          const rect = this.svgRect(p.x, p.y, pw, ph, color, "#0f1117", 1.5)
          rect.setAttribute("opacity", "0.8")
          svg.appendChild(rect)

          const pFontSize = Math.min(Math.min(pw, ph) * 0.12, 70)
          const inset = pFontSize * 0.8

          const topW = this.svgText(p.x + pw / 2, p.y + inset, `${pw}`, pFontSize)
          topW.setAttribute("class", "select-none pointer-events-none")
          topW.setAttribute("fill", "#1a202c")
          svg.appendChild(topW)

          const leftH = this.svgText(p.x + inset, p.y + ph / 2, `${ph}`, pFontSize)
          leftH.setAttribute("class", "select-none pointer-events-none")
          leftH.setAttribute("fill", "#1a202c")
          leftH.setAttribute("transform", `rotate(-90, ${p.x + inset}, ${p.y + ph / 2})`)
          svg.appendChild(leftH)

          const label = labelMap[key]
          if (label) {
            const labelFontSize = pFontSize
            const labelEl = this.svgText(p.x + pw / 2, p.y + ph / 2, label, labelFontSize)
            labelEl.setAttribute("class", "select-none pointer-events-none")
            labelEl.setAttribute("fill", "#4a5568")
            labelEl.setAttribute("font-weight", "400")
            svg.appendChild(labelEl)
          }
        }
      })

      container.appendChild(svg)
    })

    // Summary
    const summary = document.createElement("p")
    summary.className = "mt-4 text-sm text-gray-600"
    const summaryTpl = this.summaryTemplateValue || "%{count} sheet(s) — Overall waste: %{waste}%"
    summary.textContent = summaryTpl.replace("%{count}", data.sheet_count).replace("%{waste}", parseFloat(data.waste_percent).toFixed(1))
    container.appendChild(summary)
  }

  renderToolbar(container) {
    if (this.readonlyValue) return

    // Render into the shared toolbar target if available, otherwise inline
    const toolbar = this.hasToolbarTarget ? this.toolbarTarget : document.createElement("div")
    toolbar.innerHTML = ""
    if (!this.hasToolbarTarget) {
      toolbar.className = "flex flex-wrap gap-2 mb-4"
    }

    // Edit mode toggle
    const editBtn = document.createElement("button")
    editBtn.className = this.editMode
      ? "inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-blue-600 rounded-lg shadow-sm hover:bg-blue-700"
      : "inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg shadow-sm hover:bg-gray-50"
    editBtn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" /></svg>`
    editBtn.innerHTML += this.editMode ? (this.editingLabelValue || "Editing...") : (this.editLabelValue || "Edit Layout")
    editBtn.addEventListener("click", () => this.toggleEditMode())
    toolbar.appendChild(editBtn)

    // Save button (visible in edit mode)
    if (this.editMode) {
      const saveBtn = document.createElement("button")
      saveBtn.className = "inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-green-600 border border-green-600 rounded-lg shadow-sm hover:bg-green-700"
      saveBtn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" /></svg>`
      saveBtn.innerHTML += this.saveLabelValue || "Save Layout"
      saveBtn.addEventListener("click", () => this.saveLayout())
      toolbar.appendChild(saveBtn)
    }

    // Reset button (visible when edited result exists)
    const hasEdits = this.editedResultValue && this.editedResultValue.sheets
    if (hasEdits && !this.editMode) {
      const resetBtn = document.createElement("button")
      resetBtn.className = "inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-red-700 bg-white border border-red-300 rounded-lg shadow-sm hover:bg-red-50"
      resetBtn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" /></svg>`
      resetBtn.innerHTML += this.resetLabelValue || "Reset to Original"
      resetBtn.addEventListener("click", () => this.resetLayout())
      toolbar.appendChild(resetBtn)
    }

    if (!this.hasToolbarTarget) {
      container.appendChild(toolbar)
    }
  }

  // --- Drag and drop ---

  onPointerDown(e, group, svg, sheetIndex, placementIndex) {
    e.preventDefault()
    e.stopPropagation()

    const pt = this.svgPoint(svg, e.clientX, e.clientY)
    const placement = this.workingData.sheets[sheetIndex].placements[placementIndex]
    const data = this.getDisplayData()
    const stock = { w: data.stock.w ?? data.stock.length, h: data.stock.h ?? data.stock.width }

    this.dragging = {
      group,
      svg,
      sheetIndex,
      placementIndex,
      offsetX: pt.x - placement.x,
      offsetY: pt.y - placement.y,
      stock,
    }

    group.style.cursor = "grabbing"
    group.style.opacity = "0.6"
    // Bring to front
    svg.appendChild(group)

    svg.setPointerCapture(e.pointerId)
  }

  onPointerMove(e, svg) {
    if (!this.dragging || this.dragging.svg !== svg) return
    e.preventDefault()

    const { sheetIndex, placementIndex, stock } = this.dragging
    const sheet = this.workingData.sheets[sheetIndex]
    const moving = sheet.placements[placementIndex]
    const mw = moving.rect.w ?? moving.rect.length
    const mh = moving.rect.h ?? moving.rect.width

    const pt = this.svgPoint(svg, e.clientX, e.clientY)
    let newX = pt.x - this.dragging.offsetX
    let newY = pt.y - this.dragging.offsetY

    // Clamp to stock panel boundaries
    newX = Math.max(0, Math.min(newX, stock.w - mw))
    newY = Math.max(0, Math.min(newY, stock.h - mh))

    const prevX = this.dragging.currentX ?? moving.x
    const prevY = this.dragging.currentY ?? moving.y

    // Try full move first
    if (!this.hasCollision(newX, newY, mw, mh, sheet.placements, placementIndex)) {
      this.dragging.currentX = newX
      this.dragging.currentY = newY
    }
    // Try X only (slide horizontally along a piece edge)
    else if (!this.hasCollision(newX, prevY, mw, mh, sheet.placements, placementIndex)) {
      this.dragging.currentX = newX
      this.dragging.currentY = prevY
    }
    // Try Y only (slide vertically along a piece edge)
    else if (!this.hasCollision(prevX, newY, mw, mh, sheet.placements, placementIndex)) {
      this.dragging.currentX = prevX
      this.dragging.currentY = newY
    }
    // Both axes blocked — don't move

    this.dragging.group.setAttribute("transform", `translate(${this.dragging.currentX}, ${this.dragging.currentY})`)
  }

  hasCollision(x, y, w, h, placements, skipIndex) {
    for (let i = 0; i < placements.length; i++) {
      if (i === skipIndex) continue
      const other = placements[i]
      const ow = other.rect.w ?? other.rect.length
      const oh = other.rect.h ?? other.rect.width

      if (x < other.x + ow && x + w > other.x && y < other.y + oh && y + h > other.y) {
        return true
      }
    }
    return false
  }

  onPointerUp() {
    if (!this.dragging) return

    const { sheetIndex, placementIndex, currentX, currentY, group } = this.dragging
    group.style.cursor = "grab"
    group.style.opacity = "1"

    if (currentX !== undefined && currentY !== undefined) {
      const dropX = Math.round(currentX)
      const dropY = Math.round(currentY)

      // Update data — position is already collision-free from drag resolution
      this.workingData.sheets[sheetIndex].placements[placementIndex].x = dropX
      this.workingData.sheets[sheetIndex].placements[placementIndex].y = dropY
      group.setAttribute("transform", `translate(${dropX}, ${dropY})`)
    }

    this.dragging = null
  }

  svgPoint(svg, clientX, clientY) {
    const pt = svg.createSVGPoint()
    pt.x = clientX
    pt.y = clientY
    return pt.matrixTransform(svg.getScreenCTM().inverse())
  }

  // --- Helpers ---

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
