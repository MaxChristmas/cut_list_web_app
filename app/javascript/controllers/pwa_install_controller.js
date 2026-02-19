import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "iosInstructions"]

  connect() {
    // Already installed as PWA — hide everything
    if (window.matchMedia("(display-mode: standalone)").matches || navigator.standalone) {
      return
    }

    // iOS Safari: no beforeinstallprompt, show manual instructions
    if (this.hasIosInstructionsTarget && this.#isIos()) {
      this.iosInstructionsTarget.classList.remove("hidden")
      return
    }

    // Chromium browsers: capture the install prompt
    this.boundPrompt = (e) => {
      e.preventDefault()
      this.deferredPrompt = e
      if (this.hasButtonTarget) {
        this.buttonTarget.classList.remove("hidden")
        this.buttonTarget.classList.add("flex")
      }
    }
    window.addEventListener("beforeinstallprompt", this.boundPrompt)
  }

  disconnect() {
    if (this.boundPrompt) {
      window.removeEventListener("beforeinstallprompt", this.boundPrompt)
    }
  }

  async install() {
    if (!this.deferredPrompt) return

    this.deferredPrompt.prompt()
    const { outcome } = await this.deferredPrompt.userChoice
    if (outcome === "accepted") {
      this.buttonTarget.classList.add("hidden")
      this.buttonTarget.classList.remove("flex")
    }
    this.deferredPrompt = null
  }

  #isIos() {
    return /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream
  }
}
