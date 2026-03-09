import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "tab", "panel", "error", "promo", "success"]
  static values = { message: String }

  connect() {
    if (this.messageValue) {
      this.showPromo(this.messageValue)
      this.activateSignUpTab()
      this.dialogTarget.showModal()
    }

    this._boundOpenFromEvent = this._openFromEvent.bind(this)
    window.addEventListener("open-login-modal", this._boundOpenFromEvent)
  }

  disconnect() {
    window.removeEventListener("open-login-modal", this._boundOpenFromEvent)
  }

  _openFromEvent(event) {
    const message = event.detail?.message
    if (message) {
      this.showPromo(message)
      this.activateSignUpTab()
    }
    this.dialogTarget.showModal()
  }

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  backdropClose(event) {
    if (event.target === this.dialogTarget) {
      this.dialogTarget.close()
    }
  }

  switchTab(event) {
    this._activateTab(event.currentTarget.dataset.tab)
  }

  async submitForm(event) {
    event.preventDefault()
    const form = event.target
    const formData = new FormData(form)

    try {
      const response = await fetch(form.action, {
        method: form.method,
        body: formData,
        headers: {
          "Accept": "text/html",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        redirect: "follow"
      })

      if (response.redirected || response.ok) {
        window.location.href = response.url || "/"
      } else {
        const html = await response.text()
        const doc = new DOMParser().parseFromString(html, "text/html")
        const alert = doc.querySelector(".alert, .flash-alert, [data-alert]")

        this.showError(alert?.textContent?.trim() || this.errorTarget.dataset.fallback)
      }
    } catch {
      this.showError(this.errorTarget.dataset.fallback)
    }
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  clearErrors() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }

  clearSuccess() {
    if (!this.hasSuccessTarget) return
    this.successTarget.classList.add("hidden")
  }

  showPromo(message) {
    if (!this.hasPromoTarget) return
    this.promoTarget.textContent = message
    this.promoTarget.classList.remove("hidden")
  }

  togglePromo(visible) {
    if (!this.hasPromoTarget || !this.messageValue) return
    this.promoTarget.classList.toggle("hidden", !visible)
  }

  showForgotPassword() {
    this._activateTab("forgot_password")
  }

  showSignIn() {
    this._activateTab("sign_in")
  }

  async submitPasswordReset(event) {
    event.preventDefault()
    const form = event.target
    const formData = new FormData(form)

    try {
      await fetch(form.action, {
        method: form.method,
        body: formData,
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        }
      })

      // Always show success message (server always returns 200)
      this.clearErrors()
      if (this.hasSuccessTarget) {
        this.successTarget.classList.remove("hidden")
      }
      form.reset()
    } catch {
      this.showError(this.errorTarget.dataset.fallback)
    }
  }

  activateSignUpTab() {
    this._activateTab("sign_up")
  }

  _activateTab(tab) {
    this.tabTargets.forEach(t => {
      const active = t.dataset.tab === tab
      t.classList.toggle("text-white", active)
      t.classList.toggle("border-white", active)
      t.classList.toggle("text-gray-500", !active)
      t.classList.toggle("border-transparent", !active)
      // Show/hide the forgot_password tab (hidden by default)
      if (t.dataset.tab === "forgot_password") {
        t.classList.toggle("hidden", tab !== "forgot_password")
      }
    })

    this.panelTargets.forEach(p => {
      p.classList.toggle("hidden", p.dataset.tab !== tab)
    })

    this.clearErrors()
    this.clearSuccess()
    this.togglePromo(tab === "sign_up")
  }
}
