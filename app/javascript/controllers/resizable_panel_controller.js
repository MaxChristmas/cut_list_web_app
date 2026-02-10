import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.dragging = false
    this.handleMouseMove = this.onMouseMove.bind(this)
    this.handleMouseUp = this.onMouseUp.bind(this)
  }

  startDrag(event) {
    event.preventDefault()
    this.dragging = true
    document.addEventListener("mousemove", this.handleMouseMove)
    document.addEventListener("mouseup", this.handleMouseUp)
    document.body.style.cursor = "col-resize"
    document.body.style.userSelect = "none"
  }

  onMouseMove(event) {
    if (!this.dragging) return
    const container = this.element
    const rect = container.getBoundingClientRect()
    const percentage = ((event.clientX - rect.left) / rect.width) * 100
    const clamped = Math.min(Math.max(percentage, 15), 60)
    this.panelTarget.style.width = `${clamped}%`
  }

  onMouseUp() {
    this.dragging = false
    document.removeEventListener("mousemove", this.handleMouseMove)
    document.removeEventListener("mouseup", this.handleMouseUp)
    document.body.style.cursor = ""
    document.body.style.userSelect = ""
  }

  disconnect() {
    document.removeEventListener("mousemove", this.handleMouseMove)
    document.removeEventListener("mouseup", this.handleMouseUp)
  }
}
