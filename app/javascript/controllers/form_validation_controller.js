import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["stockLength", "stockWidth", "stockError", "piecesBody", "pieceError", "submitButton", "piecesLimitBanner", "submitWrapper"]
  static values = { maxPieces: { type: Number, default: Infinity } }

  connect() {
    this.validate()
    this._observer = new MutationObserver(() => this.validate())
    if (this.hasPiecesBodyTarget) {
      this._observer.observe(this.piecesBodyTarget, { childList: true })
    }
  }

  disconnect() {
    this._observer?.disconnect()
  }

  validate() {
    const stockValid = this.validateStock()
    const piecesValid = this.validatePieces()
    const overLimit = this.checkPiecesLimit()
    const hasSubmit = this.hasSubmitButtonTarget

    if (hasSubmit) {
      const disabled = !stockValid || !piecesValid || overLimit
      this.submitButtonTarget.disabled = disabled
      this.submitButtonTarget.classList.toggle("opacity-50", disabled)
      this.submitButtonTarget.classList.toggle("cursor-not-allowed", disabled)
    }

    if (this.hasSubmitWrapperTarget) {
      this.submitWrapperTarget.classList.toggle("hidden", overLimit)
    }

    if (this.hasPiecesLimitBannerTarget) {
      this.piecesLimitBannerTarget.classList.toggle("hidden", !overLimit)
    }
  }

  validateStock() {
    const l = parseFloat(this.stockLengthTarget.value)
    const w = parseFloat(this.stockWidthTarget.value)

    if (!this.stockLengthTarget.value || !this.stockWidthTarget.value) {
      this.stockErrorTarget.textContent = ""
      this.stockErrorTarget.hidden = true
      return false
    }

    if (l < w) {
      this.stockErrorTarget.textContent = this.stockErrorTarget.dataset.lengthWidthMessage
      this.stockErrorTarget.hidden = false
      this.stockWidthTarget.classList.add("border-red-500")
      return false
    }

    this.stockErrorTarget.textContent = ""
    this.stockErrorTarget.hidden = true
    this.stockWidthTarget.classList.remove("border-red-500")
    return true
  }

  validatePieces() {
    let allValid = true
    let hasPiece = false
    const rows = this.piecesBodyTarget.querySelectorAll("tr")

    rows.forEach(row => {
      const lengthInput = row.querySelector("input[name='pieces[][length]']")
      const widthInput = row.querySelector("input[name='pieces[][width]']")
      if (!lengthInput || !widthInput) return

      const l = parseFloat(lengthInput.value)
      const w = parseFloat(widthInput.value)
      const filled = lengthInput.value && widthInput.value

      if (filled) hasPiece = true

      if (filled && l < w) {
        widthInput.classList.add("border-red-500")
        allValid = false
      } else {
        widthInput.classList.remove("border-red-500")
      }
    })

    if (!allValid) {
      this.pieceErrorTarget.textContent = this.pieceErrorTarget.dataset.lengthWidthMessage
      this.pieceErrorTarget.hidden = false
    } else {
      this.pieceErrorTarget.textContent = ""
      this.pieceErrorTarget.hidden = true
    }

    return allValid && hasPiece
  }

  checkPiecesLimit() {
    if (this.maxPiecesValue === Infinity || this.maxPiecesValue === 0) return false

    let total = 0
    const rows = this.piecesBodyTarget.querySelectorAll("tr")
    rows.forEach(row => {
      const qtyInput = row.querySelector("input[name='pieces[][quantity]']")
      if (qtyInput && qtyInput.value) {
        total += parseInt(qtyInput.value, 10) || 0
      }
    })

    return total > this.maxPiecesValue
  }
}
