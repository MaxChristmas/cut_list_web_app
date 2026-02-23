import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "reading", "trigger"]

  connect() {
    this._closeOnClickOutside = this._closeOnClickOutside.bind(this)
  }

  toggle() {
    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    const menu = this.menuTarget
    menu.classList.remove("hidden")

    // Position the menu above the trigger using fixed positioning
    // so it escapes the sidebar's overflow-hidden
    if (this.hasTriggerTarget) {
      const rect = this.triggerTarget.getBoundingClientRect()
      const minWidth = 220
      const width = Math.max(rect.width, minWidth)
      menu.style.position = "fixed"
      menu.style.left = `${rect.left}px`
      menu.style.width = `${width}px`
      menu.style.bottom = `${window.innerHeight - rect.top + 4}px`
      menu.style.removeProperty("top")
    }

    requestAnimationFrame(() => {
      document.addEventListener("click", this._closeOnClickOutside)
    })
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.closeReading()
    document.removeEventListener("click", this._closeOnClickOutside)
  }

  toggleReading(event) {
    event.stopPropagation()
    if (this.hasReadingTarget) {
      this.readingTarget.classList.toggle("hidden")
    }
  }

  closeReading() {
    if (this.hasReadingTarget) {
      this.readingTarget.classList.add("hidden")
    }
  }

  _closeOnClickOutside(event) {
    if (!this.element.contains(event.target) && !this.menuTarget.contains(event.target)) {
      this.close()
    }
  }

  disconnect() {
    document.removeEventListener("click", this._closeOnClickOutside)
  }
}
