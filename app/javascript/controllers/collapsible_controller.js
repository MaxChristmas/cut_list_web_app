import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body", "icon"]
  static values = { key: { type: String, default: "collapsible-options" } }

  connect() {
    if (localStorage.getItem(this.keyValue) === "open") {
      this.#open(false)
    }
  }

  toggle() {
    const isCollapsed = this.bodyTarget.classList.contains("grid-rows-[0fr]")
    if (isCollapsed) {
      this.#open(true)
    } else {
      this.#close(true)
    }
  }

  #open(save) {
    this.bodyTarget.classList.replace("grid-rows-[0fr]", "grid-rows-[1fr]")
    if (this.hasIconTarget) this.iconTarget.classList.add("rotate-180")
    if (save) localStorage.setItem(this.keyValue, "open")
  }

  #close(save) {
    this.bodyTarget.classList.replace("grid-rows-[1fr]", "grid-rows-[0fr]")
    if (this.hasIconTarget) this.iconTarget.classList.remove("rotate-180")
    if (save) localStorage.setItem(this.keyValue, "closed")
  }
}
