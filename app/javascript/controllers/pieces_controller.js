import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body", "template"]

  add() {
    const content = this.templateTarget.content.cloneNode(true)
    this.bodyTarget.appendChild(content)
  }

  remove(event) {
    event.currentTarget.closest("tr").remove()
  }
}
