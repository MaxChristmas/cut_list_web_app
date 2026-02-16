import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "label", "overlay"]

  connect() {
    const collapsed = localStorage.getItem("sidebar_collapsed") === "true"
    if (collapsed) {
      this.collapse(false)
    }
  }

  // Desktop toggle (collapse/expand)
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
    sidebar.classList.remove("w-[260px]")
    sidebar.classList.add("w-[52px]")
    this.labelTargets.forEach(el => el.classList.add("hidden"))
    if (!animate) requestAnimationFrame(() => sidebar.classList.add("transition-all", "duration-200"))
    localStorage.setItem("sidebar_collapsed", "true")
  }

  expand() {
    const sidebar = this.sidebarTarget
    sidebar.dataset.collapsed = "false"
    sidebar.classList.remove("w-[52px]")
    sidebar.classList.add("w-[260px]")
    this.labelTargets.forEach(el => el.classList.remove("hidden"))
    localStorage.setItem("sidebar_collapsed", "false")
  }

  // Mobile: open sidebar as full-screen overlay
  toggleMobile() {
    const sidebar = this.sidebarTarget
    if (sidebar.classList.contains("max-md:-translate-x-full")) {
      this.openMobile()
    } else {
      this.closeMobile()
    }
  }

  openMobile() {
    const sidebar = this.sidebarTarget
    sidebar.classList.remove("max-md:-translate-x-full")
    sidebar.classList.add("max-md:translate-x-0")
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove("hidden")
    }
    document.body.classList.add("overflow-hidden")
  }

  closeMobile() {
    const sidebar = this.sidebarTarget
    sidebar.classList.add("max-md:-translate-x-full")
    sidebar.classList.remove("max-md:translate-x-0")
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add("hidden")
    }
    document.body.classList.remove("overflow-hidden")
  }
}
