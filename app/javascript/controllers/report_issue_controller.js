import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "form", "textarea", "thanks", "submitBtn"]
  static values = { url: String }

  open() {
    this.formTarget.classList.remove("hidden")
    this.thanksTarget.classList.add("hidden")
    this.textareaTarget.value = ""
    this.submitBtnTarget.disabled = false
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

  async submit(event) {
    event.preventDefault()
    const body = this.textareaTarget.value.trim()
    if (!body) return

    this.submitBtnTarget.disabled = true

    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
      },
      body: JSON.stringify({ report_issue: { body, page_url: window.location.href } })
    })

    if (response.ok) {
      this.formTarget.classList.add("hidden")
      this.thanksTarget.classList.remove("hidden")
    } else {
      this.submitBtnTarget.disabled = false
    }
  }
}
