import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this._autoSubmit()
  }

  saveAndPrompt({ params: { message } }) {
    const formData = new FormData(this.element)
    const entries = []
    for (const [key, value] of formData.entries()) {
      if (key === "authenticity_token" || key === "_method") continue
      entries.push([key, value])
    }
    sessionStorage.setItem("pendingProject", JSON.stringify(entries))
    window.dispatchEvent(new CustomEvent("open-login-modal", {
      detail: { message }
    }))
  }

  _autoSubmit() {
    const raw = sessionStorage.getItem("pendingProject")
    if (!raw) return

    sessionStorage.removeItem("pendingProject")
    const entries = JSON.parse(raw)

    const form = document.createElement("form")
    form.method = "POST"
    form.action = this.element.dataset.pendingProjectCreateUrlValue || "/projects"
    form.style.display = "none"

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    if (csrf) {
      this._addInput(form, "authenticity_token", csrf)
    }

    for (const [key, value] of entries) {
      this._addInput(form, key, value)
    }

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
