import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "arrow", "buttonLabel"]

  connect() {
    // Auto-collapse on mobile if flagged from a previous submission
    if (window.innerWidth < 768 && sessionStorage.getItem("form_panel_collapsed") === "true") {
      this.collapse()
      sessionStorage.removeItem("form_panel_collapsed")
    }
  }

  toggle() {
    if (this.panelTarget.classList.contains("max-md:hidden")) {
      this.open()
    } else {
      this.collapse()
    }
  }

  open() {
    this.panelTarget.classList.remove("max-md:hidden")
    this.arrowTarget.classList.add("rotate-180")
  }

  collapse() {
    this.panelTarget.classList.add("max-md:hidden")
    this.arrowTarget.classList.remove("rotate-180")
  }

  submitAndCollapse() {
    if (window.innerWidth < 768) {
      sessionStorage.setItem("form_panel_collapsed", "true")
    }
  }
}
