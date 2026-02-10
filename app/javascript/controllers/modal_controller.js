import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "tab", "panel", "error"]

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
    const tab = event.currentTarget.dataset.tab

    this.tabTargets.forEach(t => {
      const active = t.dataset.tab === tab
      t.classList.toggle("text-white", active)
      t.classList.toggle("border-white", active)
      t.classList.toggle("text-gray-500", !active)
      t.classList.toggle("border-transparent", !active)
    })

    this.panelTargets.forEach(p => {
      p.classList.toggle("hidden", p.dataset.tab !== tab)
    })

    this.clearErrors()
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
}
