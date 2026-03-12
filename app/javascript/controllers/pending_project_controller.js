import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "pendingProject"
const CHECKOUT_KEY = "pendingCheckout"
const MAX_AGE_MS = 60 * 60 * 1000 // 1 hour

export default class extends Controller {
  static values = { createUrl: String, checkoutUrl: String }

  connect() {
    this._boundPendingCheckout = this._handlePendingCheckout.bind(this)
    window.addEventListener("pending-checkout", this._boundPendingCheckout)

    this._restoreFormData()
    this._autoCheckout()
  }

  disconnect() {
    window.removeEventListener("pending-checkout", this._boundPendingCheckout)
  }

  saveAndPrompt({ params: { message } }) {
    this._saveFormData()
    window.dispatchEvent(new CustomEvent("open-login-modal", {
      detail: { message }
    }))
  }

  _handlePendingCheckout(event) {
    const { plan, billing } = event.detail
    this._saveFormData()
    localStorage.setItem(CHECKOUT_KEY, JSON.stringify({ plan, billing }))
    window.dispatchEvent(new CustomEvent("open-login-modal", {
      detail: { message: "" }
    }))
  }

  _saveFormData() {
    const formData = new FormData(this.element)
    const entries = []
    for (const [key, value] of formData.entries()) {
      if (key === "authenticity_token" || key === "_method") continue
      entries.push([key, value])
    }
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ entries, savedAt: Date.now() }))
  }

  _restoreFormData() {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return

    const data = JSON.parse(raw)

    // Expire after 1 hour
    if (Date.now() - data.savedAt > MAX_AGE_MS) {
      localStorage.removeItem(STORAGE_KEY)
      return
    }

    const entries = data.entries
    const hasPendingCheckout = !!localStorage.getItem(CHECKOUT_KEY)

    // Keep data if Stripe checkout is pending (will need it after return)
    if (!hasPendingCheckout) {
      localStorage.removeItem(STORAGE_KEY)
    }

    // Count how many piece rows we need
    const pieceEntries = entries.filter(([k]) => k === "pieces[][length]")
    const existingRows = this.element.querySelectorAll("[data-pieces-target='body'] tr")

    // Add rows if needed
    const addBtn = this.element.querySelector("[data-action*='pieces#add']")
    if (addBtn) {
      for (let i = existingRows.length; i < pieceEntries.length; i++) {
        addBtn.click()
      }
    }

    // Fill in all fields by name, in order
    const counters = {}
    for (const [name, value] of entries) {
      counters[name] = (counters[name] || 0)
      const inputs = this.element.querySelectorAll(`[name="${CSS.escape(name)}"]`)
      const input = inputs[counters[name]]
      if (input) {
        input.value = value
        input.dispatchEvent(new Event("input", { bubbles: true }))
      }
      counters[name]++
    }
  }

  _autoCheckout() {
    const checkout = localStorage.getItem(CHECKOUT_KEY)
    if (!checkout) return

    localStorage.removeItem(CHECKOUT_KEY)
    const { plan, billing } = JSON.parse(checkout)

    const form = document.createElement("form")
    form.method = "POST"
    form.action = this.checkoutUrlValue || "/plans/checkout"
    form.style.display = "none"

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    if (csrf) {
      this._addInput(form, "authenticity_token", csrf)
    }
    this._addInput(form, "plan", plan)
    this._addInput(form, "billing_cycle", billing)

    document.body.appendChild(form)
    form.submit()
  }

  _addInput(form, name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    form.appendChild(input)
  }
}
