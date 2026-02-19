import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "arrow", "buttonLabel", "dragHandle", "desktopToggle"]

  connect() {
    // Auto-collapse on mobile if flagged from a previous submission
    if (window.innerWidth < 768 && sessionStorage.getItem("form_panel_collapsed") === "true") {
      this.collapse()
      sessionStorage.removeItem("form_panel_collapsed")
    }
  }

  // Mobile toggle
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

  // Desktop toggle
  toggleDesktop() {
    if (this.panelTarget.dataset.collapsed === "true") {
      this.expandDesktop()
    } else {
      this.collapseDesktop()
    }
  }

  collapseDesktop() {
    // Store current width for restoration
    this.panelTarget.dataset.previousWidth = this.panelTarget.style.width || ""
    this.panelTarget.dataset.collapsed = "true"
    this.panelTarget.style.width = "0"
    this.panelTarget.style.padding = "0"
    this.panelTarget.style.overflow = "hidden"
    this.panelTarget.style.borderRight = "none"
    if (this.hasDragHandleTarget) this.dragHandleTarget.style.display = "none"
    this.updateDesktopToggleIcon(true)
  }

  expandDesktop() {
    this.panelTarget.dataset.collapsed = "false"
    this.panelTarget.style.width = this.panelTarget.dataset.previousWidth || ""
    this.panelTarget.style.padding = ""
    this.panelTarget.style.overflow = ""
    this.panelTarget.style.borderRight = ""
    if (this.hasDragHandleTarget) this.dragHandleTarget.style.display = ""
    this.updateDesktopToggleIcon(false)
  }

  updateDesktopToggleIcon(collapsed) {
    if (!this.hasDesktopToggleTarget) return
    const icon = this.desktopToggleTarget.querySelector("svg")
    if (icon) icon.style.transform = collapsed ? "rotate(180deg)" : ""
  }

  submitAndCollapse() {
    if (window.innerWidth < 768) {
      sessionStorage.setItem("form_panel_collapsed", "true")
    }
  }
}
