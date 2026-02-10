import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body", "template", "csvInput"]

  add() {
    const content = this.templateTarget.content.cloneNode(true)
    this.bodyTarget.appendChild(content)
  }

  remove(event) {
    event.currentTarget.closest("tr").remove()
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

      for (let i = start; i < lines.length; i++) {
        const cols = lines[i].split(/[,;\t]/).map(c => c.trim())
        const length = parseFloat(cols[0])
        const width = parseFloat(cols[1])
        const quantity = parseFloat(cols[2]) || 1
        if (isNaN(length) || isNaN(width)) continue

        const row = this.templateTarget.content.cloneNode(true)
        const inputs = row.querySelectorAll("input[type='number']")
        inputs[0].value = length  // length
        inputs[1].value = width   // width
        inputs[2].value = quantity // quantity
        this.bodyTarget.appendChild(row)
      }

      // Reset the input so re-importing the same file triggers change
      event.target.value = ""
    }
    reader.readAsText(file)
  }
}
