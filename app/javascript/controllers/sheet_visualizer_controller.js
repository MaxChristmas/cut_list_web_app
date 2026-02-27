import { Controller } from "@hotwired/stimulus"
import { COLORS, normalizeKey } from "../utils/piece_colors"

export default class extends Controller {
  static targets = ["toolbar", "canvas", "pdfLink"]
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
    colorsLabel: String,
    noColorsLabel: String,
    readonly: { type: Boolean, default: false },
    grainDirection: { type: String, default: "none" },
    grainImage: { type: String, default: "" },
  }

  connect() {
    this.editMode = false
    this.colorsEnabled = true
    this.dragging = null
    this.workingData = null
    this.zoomLevel = 1
    this._onContainerPointerMove = this.onContainerPointerMove.bind(this)
    this._onContainerPointerUp = this.onContainerPointerUp.bind(this)
    this.render()
  }

  grainDirectionValueChanged() {
    if (this.getDisplayData()?.sheets) this.render()
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
      svg.setAttribute("width", actualWidth * this.zoomLevel)
      svg.setAttribute("height", actualHeight * this.zoomLevel)
      svg.setAttribute("viewBox", `${-labelMargin} ${-labelMargin} ${svgW} ${svgHTotal}`)
      svg.setAttribute("class", "rounded")
      svg.dataset.sheetIndex = i

      if (this.editMode) {
        svg.style.cursor = "default"
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
        const key = normalizeKey(rw, rh, p.rotated)
        const color = this.colorsEnabled ? (colorMap[key] || "#a0aec0") : "#E2E8F0"

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

      // Grain direction image overlay — tiled pattern on top of pieces
      if (this.grainDirectionValue !== "none" && this.grainImageValue) {
        const patternId = `grain-pattern-${i}`
        const tileW = 300
        const tileH = Math.round(300 * (950 / 1400))

        const defs = document.createElementNS("http://www.w3.org/2000/svg", "defs")
        const pattern = document.createElementNS("http://www.w3.org/2000/svg", "pattern")
        pattern.setAttribute("id", patternId)
        pattern.setAttribute("patternUnits", "userSpaceOnUse")
        pattern.setAttribute("width", tileW)
        pattern.setAttribute("height", tileH)

        if (this.grainDirectionValue === "along_width") {
          const cx = stock.w / 2
          const cy = stock.h / 2
          pattern.setAttribute("patternTransform", `rotate(90, ${cx}, ${cy})`)
        }

        const img = document.createElementNS("http://www.w3.org/2000/svg", "image")
        img.setAttribute("href", this.grainImageValue)
        img.setAttribute("x", 0)
        img.setAttribute("y", 0)
        img.setAttribute("width", tileW)
        img.setAttribute("height", tileH)
        img.setAttribute("preserveAspectRatio", "none")
        pattern.appendChild(img)
        defs.appendChild(pattern)
        svg.appendChild(defs)

        const grainRect = document.createElementNS("http://www.w3.org/2000/svg", "rect")
        grainRect.setAttribute("x", 0)
        grainRect.setAttribute("y", 0)
        grainRect.setAttribute("width", stock.w)
        grainRect.setAttribute("height", stock.h)
        grainRect.setAttribute("fill", `url(#${patternId})`)
        grainRect.setAttribute("opacity", "0.8")
        grainRect.setAttribute("pointer-events", "none")
        svg.appendChild(grainRect)
      }

      const wrapper = document.createElement("div")
      wrapper.style.overflow = "auto"
      wrapper.style.maxHeight = "80vh"
      wrapper.addEventListener("wheel", (e) => this.onWheel(e), { passive: false })
      if (this.zoomLevel > 1) {
        wrapper.style.cursor = "grab"
        wrapper.addEventListener("pointerdown", (e) => this.onPanStart(e, wrapper))
      }
      wrapper.appendChild(svg)
      container.appendChild(wrapper)
    })

    // Container-level drag listeners for cross-sheet support
    if (this.editMode) {
      container.addEventListener("pointermove", this._onContainerPointerMove)
      container.addEventListener("pointerup", this._onContainerPointerUp)
    }

    // Broadcast color map so the pieces form can use it
    document.dispatchEvent(new CustomEvent("piece-colors:updated", { detail: { colorMap } }))

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

    // Colors toggle
    const colorsBtn = document.createElement("button")
    colorsBtn.className = this.colorsEnabled
      ? "inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg shadow-sm hover:bg-gray-50"
      : "inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-blue-600 rounded-lg shadow-sm hover:bg-blue-700"
    colorsBtn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M4.098 19.902a3.75 3.75 0 005.304 0l6.401-6.402M6.75 21A3.75 3.75 0 013 17.25V4.125C3 3.504 3.504 3 4.125 3h5.25c.621 0 1.125.504 1.125 1.125v4.072M6.75 21a3.75 3.75 0 003.75-3.75V8.197M6.75 21h13.125c.621 0 1.125-.504 1.125-1.125v-5.25c0-.621-.504-1.125-1.125-1.125h-4.072M10.5 8.197l2.88-2.88c.438-.439 1.15-.439 1.59 0l3.712 3.713c.44.44.44 1.152 0 1.59l-2.879 2.88M6.75 17.25h.008v.008H6.75v-.008z" /></svg>`
    colorsBtn.innerHTML += this.colorsEnabled
      ? (this.colorsLabelValue || "Colors")
      : (this.noColorsLabelValue || "No Colors")
    colorsBtn.addEventListener("click", () => this.toggleColors())
    toolbar.appendChild(colorsBtn)

    // Zoom controls
    const ctrlKey = navigator.platform.includes("Mac") ? "\u2318" : "Ctrl"
    const zoomGroup = document.createElement("div")
    zoomGroup.className = "inline-flex items-center rounded-lg border border-gray-300 shadow-sm overflow-hidden ml-auto"
    zoomGroup.title = `${ctrlKey} + Scroll`

    const zoomOutBtn = document.createElement("button")
    zoomOutBtn.className = "px-2.5 py-2 text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 border-r border-gray-300"
    zoomOutBtn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM13 10H7" /></svg>`
    zoomOutBtn.addEventListener("click", () => this.zoomOut())
    zoomGroup.appendChild(zoomOutBtn)

    const zoomLabel = document.createElement("button")
    zoomLabel.className = "px-2.5 py-2 text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 border-r border-gray-300 tabular-nums"
    zoomLabel.textContent = `${Math.round(this.zoomLevel * 100)}%`
    zoomLabel.title = "Reset zoom"
    zoomLabel.addEventListener("click", () => this.zoomReset())
    zoomGroup.appendChild(zoomLabel)

    const zoomInBtn = document.createElement("button")
    zoomInBtn.className = "px-2.5 py-2 text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
    zoomInBtn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v3m0 0v3m0-3h3m-3 0H7" /></svg>`
    zoomInBtn.addEventListener("click", () => this.zoomIn())
    zoomGroup.appendChild(zoomInBtn)

    toolbar.appendChild(zoomGroup)

    if (!this.hasToolbarTarget) {
      container.appendChild(toolbar)
    }
  }

  zoomIn() {
    this.zoomLevel = Math.min(this.zoomLevel + 0.25, 3)
    this.render()
  }

  zoomOut() {
    this.zoomLevel = Math.max(this.zoomLevel - 0.25, 0.5)
    this.render()
  }

  zoomReset() {
    this.zoomLevel = 1
    this.render()
  }

  onWheel(e) {
    if (!e.ctrlKey && !e.metaKey) return
    e.preventDefault()
    if (e.deltaY < 0) {
      this.zoomLevel = Math.min(this.zoomLevel + 0.1, 3)
    } else {
      this.zoomLevel = Math.max(this.zoomLevel - 0.1, 0.5)
    }
    this.render()
  }

  onPanStart(e, wrapper) {
    if (e.target.closest("g[data-sheet-index]")) return
    e.preventDefault()
    wrapper.style.cursor = "grabbing"
    const startX = e.clientX
    const startY = e.clientY
    const scrollLeft = wrapper.scrollLeft
    const scrollTop = wrapper.scrollTop

    const onMove = (me) => {
      wrapper.scrollLeft = scrollLeft - (me.clientX - startX)
      wrapper.scrollTop = scrollTop - (me.clientY - startY)
    }

    const onUp = () => {
      wrapper.style.cursor = "grab"
      window.removeEventListener("pointermove", onMove)
      window.removeEventListener("pointerup", onUp)
    }

    window.addEventListener("pointermove", onMove)
    window.addEventListener("pointerup", onUp)
  }

  toggleColors() {
    this.colorsEnabled = !this.colorsEnabled
    this.updatePdfLink()
    this.render()
  }

  updatePdfLink() {
    if (!this.hasPdfLinkTarget) return
    const url = new URL(this.pdfLinkTarget.href)
    if (this.colorsEnabled) {
      url.searchParams.delete("colors")
    } else {
      url.searchParams.set("colors", "0")
    }
    this.pdfLinkTarget.href = url.toString()
  }

  // --- Drag and drop (cross-sheet capable) ---

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
      originX: placement.x,
      originY: placement.y,
      stock,
      currentX: placement.x,
      currentY: placement.y,
      targetSheetIndex: null,
      ghost: null,
    }

    group.style.cursor = "grabbing"
    group.style.opacity = "0.6"
    // Bring to front
    svg.appendChild(group)
  }

  findSvgUnderPointer(clientX, clientY) {
    const container = this.hasCanvasTarget ? this.canvasTarget : this.element
    const svgs = container.querySelectorAll("svg[data-sheet-index]")
    for (const svg of svgs) {
      const rect = svg.getBoundingClientRect()
      if (clientX >= rect.left && clientX <= rect.right &&
          clientY >= rect.top && clientY <= rect.bottom) {
        return svg
      }
    }
    return null
  }

  onContainerPointerMove(e) {
    if (!this.dragging) return
    e.preventDefault()

    const { sheetIndex, placementIndex, stock } = this.dragging
    const sheet = this.workingData.sheets[sheetIndex]
    const moving = sheet.placements[placementIndex]
    const mw = moving.rect.w ?? moving.rect.length
    const mh = moving.rect.h ?? moving.rect.width
    const kerf = parseFloat(this.getDisplayData()?.kerf) || 0

    const targetSvg = this.findSvgUnderPointer(e.clientX, e.clientY)

    if (!targetSvg) {
      // Pointer outside all SVGs — clear ghost, keep piece at last position
      this.clearDropGhost()
      this.dragging.targetSheetIndex = null
      return
    }

    const targetIdx = parseInt(targetSvg.dataset.sheetIndex, 10)
    const pt = this.svgPoint(targetSvg, e.clientX, e.clientY)

    if (targetIdx === sheetIndex) {
      // Same sheet — normal drag with collision resolution
      this.clearDropGhost()
      this.dragging.targetSheetIndex = null

      let newX = Math.max(0, Math.min(pt.x - this.dragging.offsetX, stock.w - mw))
      let newY = Math.max(0, Math.min(pt.y - this.dragging.offsetY, stock.h - mh))

      const resolved = this.resolveCollisionsOnSheet(newX, newY, mw, mh, kerf, sheet.placements, stock, placementIndex)
      newX = resolved.x
      newY = resolved.y

      if (!this.hasCollision(newX, newY, mw, mh, sheet.placements, placementIndex)) {
        this.dragging.currentX = newX
        this.dragging.currentY = newY
      }

      this.dragging.group.setAttribute("transform", `translate(${this.dragging.currentX}, ${this.dragging.currentY})`)
    } else {
      // Cross-sheet — show ghost on target, fade source piece
      this.dragging.targetSheetIndex = targetIdx

      let newX = Math.max(0, Math.min(pt.x - this.dragging.offsetX, stock.w - mw))
      let newY = Math.max(0, Math.min(pt.y - this.dragging.offsetY, stock.h - mh))

      const targetSheet = this.workingData.sheets[targetIdx]
      const resolved = this.resolveCollisionsOnSheet(newX, newY, mw, mh, kerf, targetSheet.placements, stock, -1)
      newX = resolved.x
      newY = resolved.y

      const valid = !this.hasCollision(newX, newY, mw, mh, targetSheet.placements, -1)

      this.updateDropGhost(targetSvg, newX, newY, mw, mh, valid)
      this.dragging.crossX = newX
      this.dragging.crossY = newY
      this.dragging.crossValid = valid

      // Fade source piece more when over another sheet
      this.dragging.group.style.opacity = "0.3"
    }
  }

  resolveCollisionsOnSheet(x, y, mw, mh, kerf, placements, stock, skipIndex) {
    let newX = x
    let newY = y

    for (let pass = 0; pass < 3; pass++) {
      let collided = false
      for (let i = 0; i < placements.length; i++) {
        if (i === skipIndex) continue
        const o = placements[i]
        const ow = o.rect.w ?? o.rect.length
        const oh = o.rect.h ?? o.rect.width

        if (newX < o.x + ow + kerf && newX + mw + kerf > o.x &&
            newY < o.y + oh + kerf && newY + mh + kerf > o.y) {
          collided = true
          const pushRight = o.x + ow + kerf - newX
          const pushLeft  = newX + mw + kerf - o.x
          const pushDown  = o.y + oh + kerf - newY
          const pushUp    = newY + mh + kerf - o.y
          const min = Math.min(pushRight, pushLeft, pushDown, pushUp)

          if (min === pushRight) newX = o.x + ow + kerf
          else if (min === pushLeft) newX = o.x - mw - kerf
          else if (min === pushDown) newY = o.y + oh + kerf
          else newY = o.y - mh - kerf

          newX = Math.max(0, Math.min(newX, stock.w - mw))
          newY = Math.max(0, Math.min(newY, stock.h - mh))
        }
      }
      if (!collided) break
    }

    return { x: newX, y: newY }
  }

  hasCollision(x, y, w, h, placements, skipIndex) {
    const kerf = parseFloat(this.getDisplayData()?.kerf) || 0
    for (let i = 0; i < placements.length; i++) {
      if (i === skipIndex) continue
      const other = placements[i]
      const ow = other.rect.w ?? other.rect.length
      const oh = other.rect.h ?? other.rect.width

      if (x < other.x + ow + kerf && x + w + kerf > other.x && y < other.y + oh + kerf && y + h + kerf > other.y) {
        return true
      }
    }
    return false
  }

  updateDropGhost(targetSvg, x, y, w, h, valid) {
    this.clearDropGhost()

    const ghost = document.createElementNS("http://www.w3.org/2000/svg", "rect")
    ghost.setAttribute("x", x)
    ghost.setAttribute("y", y)
    ghost.setAttribute("width", w)
    ghost.setAttribute("height", h)
    ghost.setAttribute("fill", valid ? "rgba(59, 130, 246, 0.15)" : "rgba(239, 68, 68, 0.15)")
    ghost.setAttribute("stroke", valid ? "#3b82f6" : "#ef4444")
    ghost.setAttribute("stroke-width", "3")
    ghost.setAttribute("stroke-dasharray", "8 4")
    ghost.setAttribute("pointer-events", "none")
    ghost.dataset.dropGhost = "true"
    targetSvg.appendChild(ghost)

    this.dragging.ghost = ghost
  }

  clearDropGhost() {
    if (this.dragging?.ghost) {
      this.dragging.ghost.remove()
      this.dragging.ghost = null
    }
  }

  onContainerPointerUp(e) {
    if (!this.dragging) return

    const { sheetIndex, placementIndex, currentX, currentY, group, targetSheetIndex, crossX, crossY, crossValid, originX, originY } = this.dragging

    this.clearDropGhost()
    group.style.cursor = "grab"
    group.style.opacity = "1"

    if (targetSheetIndex !== null && targetSheetIndex !== sheetIndex) {
      // Cross-sheet drop
      if (crossValid) {
        this.transferPiece(sheetIndex, placementIndex, targetSheetIndex, Math.round(crossX), Math.round(crossY))
      } else {
        // Invalid drop — snap back to origin
        group.setAttribute("transform", `translate(${originX}, ${originY})`)
      }
    } else {
      // Same-sheet drop
      if (currentX !== undefined && currentY !== undefined) {
        const dropX = Math.round(currentX)
        const dropY = Math.round(currentY)
        this.workingData.sheets[sheetIndex].placements[placementIndex].x = dropX
        this.workingData.sheets[sheetIndex].placements[placementIndex].y = dropY
        group.setAttribute("transform", `translate(${dropX}, ${dropY})`)
      }
    }

    this.dragging = null
  }

  transferPiece(sourceIdx, placementIdx, targetIdx, x, y) {
    const sourceSheet = this.workingData.sheets[sourceIdx]
    const targetSheet = this.workingData.sheets[targetIdx]

    // Remove from source, add to target
    const [piece] = sourceSheet.placements.splice(placementIdx, 1)
    piece.x = x
    piece.y = y
    targetSheet.placements.push(piece)

    // Recalculate waste for both sheets
    this.recalcWaste(sourceSheet)
    this.recalcWaste(targetSheet)

    // Remove empty source sheet
    if (sourceSheet.placements.length === 0) {
      this.workingData.sheets.splice(sourceIdx, 1)
      this.workingData.sheet_count = this.workingData.sheets.length
    }

    // Recalculate global waste
    this.recalcGlobalWaste()

    // Re-render everything
    this.render()
  }

  recalcWaste(sheet) {
    const data = this.getDisplayData()
    const stock = { w: data.stock.w ?? data.stock.length, h: data.stock.h ?? data.stock.width }
    const stockArea = stock.w * stock.h
    let usedArea = 0
    sheet.placements.forEach((p) => {
      const pw = p.rect.w ?? p.rect.length
      const ph = p.rect.h ?? p.rect.width
      usedArea += pw * ph
    })
    sheet.waste_area = stockArea - usedArea
  }

  recalcGlobalWaste() {
    const data = this.workingData
    const stock = { w: data.stock.w ?? data.stock.length, h: data.stock.h ?? data.stock.width }
    const stockArea = stock.w * stock.h
    const totalSheets = data.sheets.length
    data.sheet_count = totalSheets

    let totalWaste = 0
    data.sheets.forEach((s) => {
      totalWaste += s.waste_area
    })
    data.waste_percent = ((totalWaste / (stockArea * totalSheets)) * 100).toFixed(1)
  }

  svgPoint(svg, clientX, clientY) {
    const pt = svg.createSVGPoint()
    pt.x = clientX
    pt.y = clientY
    return pt.matrixTransform(svg.getScreenCTM().inverse())
  }

  // --- Helpers ---

  buildLabelMap(pieces) {
    const map = {}
    pieces.forEach((p) => {
      if (!p.label) return
      const l = parseFloat(p.length) || parseFloat(p.l) || 0
      const w = parseFloat(p.width) || parseFloat(p.w) || 0
      const key = normalizeKey(l, w)
      if (!map[key]) map[key] = p.label
    })
    return map
  }

  buildColorMap(sheets) {
    const keys = new Set()
    sheets.forEach((s) => {
      s.placements.forEach((p) => {
        keys.add(normalizeKey(p.rect.w ?? p.rect.length, p.rect.h ?? p.rect.width))
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
