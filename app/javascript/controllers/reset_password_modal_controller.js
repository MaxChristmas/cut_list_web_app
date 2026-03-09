import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "error"]

  connect() {
    // Auto-open if reset_password_token is present in URL
    const params = new URLSearchParams(window.location.search)
    if (params.has("reset_password_token")) {
      this.dialogTarget.showModal()
    }
  }

  close() {
    this.dialogTarget.close()
    // Clean URL
    const url = new URL(window.location)
    url.searchParams.delete("reset_password_token")
    window.history.replaceState({}, "", url)
  }

  backdropClose(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }

  async submitForm(event) {
    event.preventDefault()
    const form = event.target
    const formData = new FormData(form)

    try {
      const response = await fetch(form.action, {
        method: "PUT",
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
        const errors = doc.querySelectorAll("#error_explanation li, .alert, .flash-alert, [data-alert]")

        const message = Array.from(errors).map(e => e.textContent.trim()).filter(Boolean).join(". ")
        this.showError(message || "An error occurred. Please try again.")
      }
    } catch {
      this.showError("An error occurred. Please try again.")
    }
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }
}
