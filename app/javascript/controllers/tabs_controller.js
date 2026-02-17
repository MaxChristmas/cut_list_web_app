import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { index: { type: Number, default: 0 } }

  connect() {
    this.select(this.indexValue)
  }

  switch(event) {
    this.select(this.tabTargets.indexOf(event.currentTarget))
  }

  select(index) {
    this.indexValue = index
    this.tabTargets.forEach((tab, i) => {
      tab.classList.toggle("border-white", i === index)
      tab.classList.toggle("text-white", i === index)
      tab.classList.toggle("border-transparent", i !== index)
      tab.classList.toggle("text-gray-500", i !== index)
    })
    this.panelTargets.forEach((panel, i) => {
      panel.classList.toggle("hidden", i !== index)
    })
  }
}
