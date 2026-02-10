import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "label"]

  connect() {
    const collapsed = localStorage.getItem("sidebar_collapsed") === "true"
    if (collapsed) {
      this.collapse(false)
    }
  }

  toggle() {
    const isCollapsed = this.sidebarTarget.dataset.collapsed === "true"
    if (isCollapsed) {
      this.expand()
    } else {
      this.collapse()
    }
  }

  collapse(animate = true) {
    const sidebar = this.sidebarTarget
    if (!animate) sidebar.classList.remove("transition-all", "duration-200")
    sidebar.dataset.collapsed = "true"
    sidebar.style.width = "52px"
    this.labelTargets.forEach(el => el.classList.add("hidden"))
    if (!animate) requestAnimationFrame(() => sidebar.classList.add("transition-all", "duration-200"))
    localStorage.setItem("sidebar_collapsed", "true")
  }

  expand() {
    const sidebar = this.sidebarTarget
    sidebar.dataset.collapsed = "false"
    sidebar.style.width = "260px"
    this.labelTargets.forEach(el => el.classList.remove("hidden"))
    localStorage.setItem("sidebar_collapsed", "false")
  }
}
