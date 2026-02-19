import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body", "template", "csvInput", "labelsToggle", "labelCol", "grainSelect", "grainCol"]
  static values = { labelsVisible: Boolean, grainVisible: Boolean }

  connect() {
    if (this.labelsVisibleValue) {
      this.showLabelColumns()
    }
    if (this.grainVisibleValue) {
      this.showGrainColumns()
    }
    this.element.closest("form")?.addEventListener("submit", this.autoFillLabels.bind(this))
  }

  add() {
    const content = this.templateTarget.content.cloneNode(true)
    if (this.labelsVisibleValue) {
      content.querySelectorAll("[data-pieces-target='labelCol']").forEach(el => el.removeAttribute("hidden"))
    }
    if (this.grainVisibleValue) {
      content.querySelectorAll("[data-pieces-target='grainCol']").forEach(el => el.removeAttribute("hidden"))
    }
    this.bodyTarget.appendChild(content)
  }

  remove(event) {
    event.currentTarget.closest("tr").remove()
  }

  toggleLabels() {
    this.labelsVisibleValue = this.labelsToggleTarget.checked
    if (this.labelsVisibleValue) {
      this.showLabelColumns()
    } else {
      this.hideLabelColumns()
    }
  }

  toggleGrain() {
    this.grainVisibleValue = this.grainSelectTarget.value !== "none"
    if (this.grainVisibleValue) {
      this.showGrainColumns()
    } else {
      this.hideGrainColumns()
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

  showGrainColumns() {
    this.grainColTargets.forEach(el => el.removeAttribute("hidden"))
  }

  hideGrainColumns() {
    this.grainColTargets.forEach(el => {
      el.setAttribute("hidden", "")
      const select = el.querySelector("select")
      if (select) select.value = "auto"
    })
  }

  autoFillLabels() {
    if (!this.labelsVisibleValue) return

    const labelInputs = this.bodyTarget.querySelectorAll("input[name='pieces[][label]']")
    const allEmpty = Array.from(labelInputs).every(input => !input.value.trim())
    if (!allEmpty) return

    const used = new Set()
    labelInputs.forEach(input => {
      let code
      do {
        code = Array.from({ length: 3 }, () => String.fromCharCode(65 + Math.floor(Math.random() * 26))).join("")
      } while (used.has(code))
      used.add(code)
      input.value = code
    })
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

        if (label && this.labelsVisibleValue) {
          const labelInput = row.querySelector("input[type='text']")
          if (labelInput) labelInput.value = label
        }

        if (this.labelsVisibleValue) {
          row.querySelectorAll("[data-pieces-target='labelCol']").forEach(el => el.removeAttribute("hidden"))
        }

        if (this.grainVisibleValue) {
          row.querySelectorAll("[data-pieces-target='grainCol']").forEach(el => el.removeAttribute("hidden"))
        }

        this.bodyTarget.appendChild(row)
      }

      // Reset the input so re-importing the same file triggers change
      event.target.value = ""
    }
    reader.readAsText(file)
  }
}
