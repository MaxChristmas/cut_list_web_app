import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tbody", "row", "warning", "addButton", "dimensionError"]
  static values = { scanTokenId: Number }

  connect() {
    this.checkValidity()
  }

  onEdit(event) {
    const row = event.target.closest("tr")
    if (row.dataset.confidence === "basse") {
      row.dataset.confidence = "edited"
      row.classList.remove("border-l-2", "border-red-500")
      row.classList.add("border-l-2", "border-yellow-500")

      const badge = row.querySelector("span.rounded-full")
      if (badge) {
        badge.className = "inline-block text-[10px] px-1.5 py-0.5 rounded-full font-medium bg-yellow-900/50 text-yellow-400"
        badge.textContent = "ok"
      }
    }
    this.checkValidity()
  }

  removeRow(event) {
    event.currentTarget.closest("tr").remove()
    this.checkValidity()
  }

  addRow() {
    const row = document.createElement("tr")
    row.className = "border-b border-gray-800"
    row.dataset.photoImportTarget = "row"
    row.dataset.confidence = "haute"
    row.innerHTML = `
      <td class="py-1.5 pr-2">
        <input type="text" data-field="label"
               class="w-full bg-gray-700 border border-gray-700 rounded px-1.5 py-0.5 text-xs text-gray-200 focus:outline-none focus:ring-1 focus:ring-blue-500">
      </td>
      <td class="py-1.5 pr-2">
        <input type="number" data-field="length" step="any" min="1"
               data-action="input->photo-import#onEdit"
               class="w-full bg-gray-700 border border-gray-700 rounded px-1.5 py-0.5 text-xs text-gray-200 focus:outline-none focus:ring-1 focus:ring-blue-500">
      </td>
      <td class="py-1.5 pr-2">
        <input type="number" data-field="width" step="any" min="1"
               data-action="input->photo-import#onEdit"
               class="w-full bg-gray-700 border border-gray-700 rounded px-1.5 py-0.5 text-xs text-gray-200 focus:outline-none focus:ring-1 focus:ring-blue-500">
      </td>
      <td class="py-1.5 pr-2">
        <input type="number" data-field="quantity" value="1" min="1"
               data-action="input->photo-import#onEdit"
               class="w-full bg-gray-700 border border-gray-700 rounded px-1.5 py-0.5 text-xs text-gray-200 focus:outline-none focus:ring-1 focus:ring-blue-500">
      </td>
      <td class="py-1.5 text-center"></td>
      <td class="py-1.5 text-center">
        <button type="button" data-action="photo-import#removeRow"
                class="text-red-400 hover:text-red-300 text-xs font-medium">&times;</button>
      </td>
    `
    this.tbodyTarget.appendChild(row)

    // Focus the length input of the new row
    row.querySelector("[data-field='length']")?.focus()
  }

  checkValidity() {
    const hasLowConfidence = this.rowTargets.some(row => row.dataset.confidence === "basse")
    const hasDimensionError = this.#hasDimensionErrors()
    const hasNoRows = this.rowTargets.length === 0

    if (this.hasWarningTarget) {
      this.warningTarget.classList.toggle("hidden", !hasLowConfidence)
    }

    if (this.hasDimensionErrorTarget) {
      this.dimensionErrorTarget.classList.toggle("hidden", !hasDimensionError)
    }

    if (this.hasAddButtonTarget) {
      this.addButtonTarget.disabled = hasLowConfidence || hasDimensionError || hasNoRows
    }
  }

  resetScan() {
    const scanButton = document.querySelector("[data-action*='scan']")
    if (scanButton) scanButton.click()
  }

  addToProject() {
    const pieces = this.rowTargets.map(row => {
      return {
        label: row.querySelector("[data-field='label']")?.value || "",
        length: parseFloat(row.querySelector("[data-field='length']")?.value) || 0,
        width: parseFloat(row.querySelector("[data-field='width']")?.value) || 0,
        quantity: parseInt(row.querySelector("[data-field='quantity']")?.value) || 1
      }
    }).filter(p => p.length > 0 && p.width > 0)

    const scanTokenId = this.scanTokenIdValue

    // Save submitted pieces server-side for tracking
    if (scanTokenId) {
      fetch(`/scan_tokens/${scanTokenId}/submit_pieces`, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ pieces })
      })
    }

    // Dispatch custom event to pieces controller with scanTokenId
    document.dispatchEvent(new CustomEvent("photo-pieces:add", {
      detail: { pieces, scanTokenId }
    }))

    // Close the modal
    const modal = document.getElementById("photo-import-modal")
    if (modal) {
      modal.classList.add("hidden")
      modal.classList.remove("flex")
    }
  }

  // Private

  #hasDimensionErrors() {
    return this.rowTargets.some(row => {
      const l = parseFloat(row.querySelector("[data-field='length']")?.value)
      const w = parseFloat(row.querySelector("[data-field='width']")?.value)
      if (isNaN(l) || isNaN(w)) return false
      return l < w
    })
  }
}
