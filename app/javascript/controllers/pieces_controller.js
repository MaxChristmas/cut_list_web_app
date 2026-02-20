import { Controller } from "@hotwired/stimulus"
import { COLORS, normalizeKey } from "../utils/piece_colors"

export default class extends Controller {
  static targets = ["body", "template", "csvInput", "labelsSelect", "labelCol", "grainSelect", "grainCol"]
  static values = { labelsMode: { type: String, default: "none" }, grainVisible: Boolean }

  connect() {
    if (this.labelsModeValue !== "none") {
      this.showLabelColumns()
      if (this.labelsModeValue === "auto") {
        this.autoFillLabels()
      }
    }
    if (this.grainVisibleValue) {
      this.showGrainColumns()
    }

    this.colorMap = null
    this._onColorsUpdated = (e) => {
      this.colorMap = e.detail.colorMap
      this.applyColors()
    }
    document.addEventListener("piece-colors:updated", this._onColorsUpdated)

    // Reapply colors when length/width inputs change
    this._onDimensionChange = (e) => {
      const name = e.target.name
      if (name === "pieces[][length]" || name === "pieces[][width]") {
        this.applyColors()
      }
    }
    this.bodyTarget.addEventListener("input", this._onDimensionChange)

    // Apply colors on next frame (visualizer may have rendered first)
    requestAnimationFrame(() => this.applyColors())
  }

  disconnect() {
    document.removeEventListener("piece-colors:updated", this._onColorsUpdated)
    this.bodyTarget.removeEventListener("input", this._onDimensionChange)
  }

  add() {
    const content = this.templateTarget.content.cloneNode(true)
    if (this.labelsModeValue !== "none") {
      content.querySelectorAll("[data-pieces-target='labelCol']").forEach(el => el.removeAttribute("hidden"))
    }
    if (this.grainVisibleValue) {
      content.querySelectorAll("[data-pieces-target='grainCol']").forEach(el => el.removeAttribute("hidden"))
    }
    this.bodyTarget.appendChild(content)
    if (this.labelsModeValue === "auto") {
      const lastRow = this.bodyTarget.lastElementChild
      this.autoFillLabel(lastRow)
    }
    this.applyColors()
  }

  remove(event) {
    event.currentTarget.closest("tr").remove()
    this.applyColors()
  }

  toggleLabels() {
    this.labelsModeValue = this.labelsSelectTarget.value
    if (this.labelsModeValue === "none") {
      this.hideLabelColumns()
    } else {
      this.showLabelColumns()
      this.flashLabelColumns()
      if (this.labelsModeValue === "auto") {
        this.autoFillLabels()
      }
    }
  }

  toggleGrain() {
    const direction = this.grainSelectTarget.value
    this.grainVisibleValue = direction !== "none"
    if (this.grainVisibleValue) {
      this.showGrainColumns()
      this.flashGrainColumns()
    } else {
      this.hideGrainColumns()
    }

    const visualizer = document.querySelector("[data-controller~='sheet-visualizer']")
    if (visualizer) {
      visualizer.setAttribute("data-sheet-visualizer-grain-direction-value", direction)
    }
  }

  showLabelColumns() {
    this.labelColTargets.forEach(el => el.removeAttribute("hidden"))
  }

  hideLabelColumns() {
    this.labelColTargets.forEach(el => {
      el.setAttribute("hidden", "")
      const input = el.querySelector("input")
      if (input) input.value = ""
    })
  }

  flashLabelColumns() {
    this.labelColTargets.forEach(el => {
      const input = el.querySelector("input")
      if (!input) return
      input.style.transition = "none"
      input.style.backgroundColor = "rgb(187 247 208)"
      requestAnimationFrame(() => {
        input.style.transition = "background-color 1s ease"
        input.style.backgroundColor = ""
      })
    })
  }

  showGrainColumns() {
    this.grainColTargets.forEach(el => el.removeAttribute("hidden"))
  }

  flashGrainColumns() {
    this.grainColTargets.forEach(el => {
      const targets = el.querySelectorAll("label span")
      if (!targets.length) return
      targets.forEach(span => {
        span.style.transition = "none"
        span.style.backgroundColor = "rgb(187 247 208)"
        span.style.color = "rgb(17 24 39)"
        requestAnimationFrame(() => {
          span.style.transition = "background-color 1s ease, color 1s ease"
          span.style.backgroundColor = ""
          span.style.color = ""
        })
      })
    })
  }

  selectGrain(event) {
    const btn = event.currentTarget
    const td = btn.closest("td")
    td.querySelector("input[type='hidden']").value = btn.value
    td.querySelectorAll("button[data-action*='selectGrain']").forEach(b => {
      b.classList.remove("bg-blue-600", "text-white")
      b.classList.add("bg-gray-700", "text-gray-400")
    })
    btn.classList.remove("bg-gray-700", "text-gray-400")
    btn.classList.add("bg-blue-600", "text-white")
  }

  hideGrainColumns() {
    this.grainColTargets.forEach(el => {
      el.setAttribute("hidden", "")
      const hidden = el.querySelector("input[type='hidden']")
      if (hidden) hidden.value = "auto"
      const autoBtn = el.querySelector("button[value='auto']")
      if (autoBtn) {
        el.querySelectorAll("button[data-action*='selectGrain']").forEach(b => {
          b.classList.remove("bg-blue-600", "text-white")
          b.classList.add("bg-gray-700", "text-gray-400")
        })
        autoBtn.classList.remove("bg-gray-700", "text-gray-400")
        autoBtn.classList.add("bg-blue-600", "text-white")
      }
    })
  }

  autoFillLabels() {
    const used = this.usedLabelCodes()
    const labelInputs = this.bodyTarget.querySelectorAll("input[name='pieces[][label]']")
    labelInputs.forEach(input => {
      if (!input.value.trim()) {
        input.value = this.generateUniqueCode(used)
      }
    })
  }

  autoFillLabel(row) {
    const input = row.querySelector("input[name='pieces[][label]']")
    if (input && !input.value.trim()) {
      input.value = this.generateUniqueCode(this.usedLabelCodes())
    }
  }

  usedLabelCodes() {
    const used = new Set()
    this.bodyTarget.querySelectorAll("input[name='pieces[][label]']").forEach(input => {
      if (input.value.trim()) used.add(input.value.trim())
    })
    return used
  }

  generateUniqueCode(used) {
    let code
    do {
      code = Array.from({ length: 3 }, () => String.fromCharCode(65 + Math.floor(Math.random() * 26))).join("")
    } while (used.has(code))
    used.add(code)
    return code
  }

  openCsvDialog() {
    this.csvInputTarget.click()
  }

  importCsv(event) {
    const file = event.target.files[0]
    if (!file) return

    const reader = new FileReader()
    reader.onload = (e) => {
      const lines = e.target.result.split(/\r?\n/).filter(line => line.trim())

      // Skip header if first line contains non-numeric values
      let start = 0
      const firstCols = lines[0].split(/[,;\t]/).map(c => c.trim())
      if (firstCols.some(c => isNaN(c) && c !== "")) start = 1

      // Clear existing pieces before importing
      this.bodyTarget.innerHTML = ""

      for (let i = start; i < lines.length; i++) {
        const cols = lines[i].split(/[,;\t]/).map(c => c.trim())
        const length = parseFloat(cols[0])
        const width = parseFloat(cols[1])
        const quantity = parseFloat(cols[2]) || 1
        const label = cols[3] || ""
        if (isNaN(length) || isNaN(width)) continue

        const row = this.templateTarget.content.cloneNode(true)
        const numberInputs = row.querySelectorAll("input[type='number']")
        numberInputs[0].value = length
        numberInputs[1].value = width
        numberInputs[2].value = quantity

        if (label && this.labelsModeValue !== "none") {
          const labelInput = row.querySelector("input[type='text']")
          if (labelInput) labelInput.value = label
        }

        if (this.labelsModeValue !== "none") {
          row.querySelectorAll("[data-pieces-target='labelCol']").forEach(el => el.removeAttribute("hidden"))
        }

        if (this.grainVisibleValue) {
          row.querySelectorAll("[data-pieces-target='grainCol']").forEach(el => el.removeAttribute("hidden"))
        }

        this.bodyTarget.appendChild(row)
      }

      if (this.labelsModeValue === "auto") {
        this.autoFillLabels()
      }

      this.applyColors()

      // Reset the input so re-importing the same file triggers change
      event.target.value = ""
    }
    reader.readAsText(file)
  }

  // --- Piece color indicators ---

  applyColors() {
    const colorMap = this.colorMap || this.buildFormColorMap()
    const rows = this.bodyTarget.querySelectorAll("tr")
    rows.forEach(row => {
      const lengthInput = row.querySelector("input[name='pieces[][length]']")
      const widthInput = row.querySelector("input[name='pieces[][width]']")
      const quantityInput = row.querySelector("input[name='pieces[][quantity]']")
      if (!lengthInput || !widthInput || !quantityInput) return

      const l = parseFloat(lengthInput.value)
      const w = parseFloat(widthInput.value)
      if (isNaN(l) || isNaN(w)) {
        quantityInput.style.backgroundColor = ""
        quantityInput.style.color = ""
        quantityInput.style.borderColor = ""
        return
      }

      const key = normalizeKey(l, w)
      const color = colorMap[key]
      if (color) {
        quantityInput.style.backgroundColor = color
        quantityInput.style.color = "#1a202c"
        quantityInput.style.borderColor = color
      }
    })
  }

  buildFormColorMap() {
    const keys = new Set()
    this.bodyTarget.querySelectorAll("tr").forEach(row => {
      const l = parseFloat(row.querySelector("input[name='pieces[][length]']")?.value)
      const w = parseFloat(row.querySelector("input[name='pieces[][width]']")?.value)
      if (!isNaN(l) && !isNaN(w)) keys.add(normalizeKey(l, w))
    })
    const map = {}
    let i = 0
    keys.forEach(k => { map[k] = COLORS[i % COLORS.length]; i++ })
    return map
  }
}
