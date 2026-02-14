import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "project", "formatLink", "dropdown", "dropdownButton", "dropdownLabel"]
  static values = { baseUrl: String, currentName: String }

  connect() {
    this.updateLinks()
    this._closeDropdownOnOutsideClick = this.closeDropdownOnOutsideClick.bind(this)
    document.addEventListener("click", this._closeDropdownOnOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this._closeDropdownOnOutsideClick)
  }

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
    this.hideDropdown()
  }

  backdropClose(event) {
    if (event.target === this.dialogTarget) {
      this.dialogTarget.close()
      this.hideDropdown()
    }
  }

  toggleDropdown(event) {
    event.stopPropagation()
    this.dropdownTarget.classList.toggle("hidden")
  }

  hideDropdown() {
    this.dropdownTarget.classList.add("hidden")
  }

  closeDropdownOnOutsideClick(event) {
    if (!this.hasDropdownTarget) return
    if (!this.dropdownTarget.contains(event.target) && !this.dropdownButtonTarget.contains(event.target)) {
      this.hideDropdown()
    }
  }

  updateLinks() {
    const checked = this.projectTargets.filter(cb => cb.checked)
    const extraTokens = checked.map(cb => cb.dataset.token)

    // Update dropdown button label
    if (this.hasDropdownLabelTarget) {
      const baseName = this.dropdownButtonTarget.dataset.currentName
      if (checked.length === 0) {
        this.dropdownLabelTarget.textContent = baseName
      } else {
        const names = checked.map(cb => cb.dataset.projectName)
        this.dropdownLabelTarget.textContent = `${baseName} + ${names.join(", ")}`
      }
    }

    this.formatLinkTargets.forEach(link => {
      const format = link.dataset.labelFormat
      const url = new URL(this.baseUrlValue, window.location.origin)
      url.searchParams.set("label_format", format)
      extraTokens.forEach(token => url.searchParams.append("tokens[]", token))
      link.href = url.pathname + url.search
    })
  }
}
