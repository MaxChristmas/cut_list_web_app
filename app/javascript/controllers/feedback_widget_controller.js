import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "step1", "step2", "step3", "thanks", "dot", "otherBtn", "otherInput"]
  static values = {
    createUrl: String,
    dismissUrl: String
  }

  feedbackId = null
  currentStep = 1

  connect() {
    setTimeout(() => {
      this.containerTarget.classList.remove("translate-y-full", "opacity-0")
    }, 1000)
  }

  selectRating(event) {
    const rating = parseInt(event.currentTarget.dataset.rating)
    this.highlightStars(rating)

    // Save immediately
    this.createFeedback({ rating }).then(() => {
      this.goToStep(2)
    })
  }

  hoverStar(event) {
    const rating = parseInt(event.currentTarget.dataset.rating)
    this.highlightStars(rating)
  }

  resetStars() {
    this.highlightStars(0)
  }

  highlightStars(count) {
    this.element.querySelectorAll("[data-star]").forEach((star) => {
      const value = parseInt(star.dataset.star)
      const filled = star.querySelector("[data-filled]")
      const empty = star.querySelector("[data-empty]")
      if (value <= count) {
        filled.classList.remove("hidden")
        empty.classList.add("hidden")
      } else {
        filled.classList.add("hidden")
        empty.classList.remove("hidden")
      }
    })
  }

  selectImprovement(event) {
    const value = event.currentTarget.dataset.value
    this.updateFeedback({ improvement: value }).then(() => {
      this.goToStep(3)
    })
  }

  showOtherImprovement() {
    this.otherBtnTarget.classList.add("hidden")
    this.otherInputTarget.classList.remove("hidden")
    this.otherInputTarget.querySelector("textarea").focus()
  }

  submitOtherImprovement() {
    const textarea = this.otherInputTarget.querySelector("textarea")
    const value = textarea.value.trim()
    if (!value) return

    this.updateFeedback({ improvement: value }).then(() => {
      this.goToStep(3)
    })
  }

  submitFeatureRequest() {
    const textarea = this.step3Target.querySelector("textarea")
    const value = textarea.value.trim()
    if (!value) return

    this.updateFeedback({ feature_request: value }).then(() => {
      this.goToStep(4)
    })
  }

  skipStep() {
    this.goToStep(this.currentStep + 1)
  }

  goToStep(step) {
    this.currentStep = step

    this.step1Target.classList.add("hidden")
    this.step2Target.classList.add("hidden")
    this.step3Target.classList.add("hidden")
    this.thanksTarget.classList.add("hidden")

    // Update progress dots
    this.dotTargets.forEach((dot, i) => {
      if (i < step - 1) {
        dot.classList.add("bg-blue-500")
        dot.classList.remove("bg-gray-600")
      } else if (i === step - 1 && step <= 3) {
        dot.classList.add("bg-blue-500")
        dot.classList.remove("bg-gray-600")
      } else {
        dot.classList.remove("bg-blue-500")
        dot.classList.add("bg-gray-600")
      }
    })

    if (step === 2) this.step2Target.classList.remove("hidden")
    else if (step === 3) this.step3Target.classList.remove("hidden")
    else if (step === 4) {
      this.thanksTarget.classList.remove("hidden")
      setTimeout(() => this.closeWidget(), 3000)
    }
  }

  dismiss() {
    fetch(this.dismissUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": this.csrfToken
      }
    })
    this.closeWidget()
  }

  closeWidget() {
    this.containerTarget.classList.add("translate-y-full", "opacity-0")
    setTimeout(() => this.element.remove(), 300)
  }

  async createFeedback(data) {
    const response = await fetch(this.createUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify({ feedback: data })
    })

    if (response.ok) {
      const json = await response.json()
      this.feedbackId = json.id
    }
  }

  async updateFeedback(data) {
    if (!this.feedbackId) return

    await fetch(`${this.createUrlValue}/${this.feedbackId}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify({ feedback: data })
    })
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
