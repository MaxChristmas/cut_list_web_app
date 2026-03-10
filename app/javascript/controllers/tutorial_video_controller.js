import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "tutorial_video_dismissed"

export default class extends Controller {
  static targets = ["widget", "dialog", "videoContainer"]
  static values = { videoId: String }

  connect() {
    if (!localStorage.getItem(STORAGE_KEY)) {
      this.widgetTarget.classList.remove("hidden")
    }

    this._onOpen = () => this.#openModal()
    document.addEventListener("tutorial-video:open", this._onOpen)
  }

  disconnect() {
    document.removeEventListener("tutorial-video:open", this._onOpen)
  }

  open(event) {
    event.preventDefault()
    this.#openModal()
  }

  close() {
    this.dialogTarget.close()
    this.#removeVideo()
  }

  dismiss(event) {
    event.preventDefault()
    event.stopPropagation()
    localStorage.setItem(STORAGE_KEY, "true")
    this.widgetTarget.classList.add("hidden")
  }

  backdropClose(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }

  #openModal() {
    this.#loadVideo()
    this.dialogTarget.showModal()
  }

  #loadVideo() {
    if (this.videoContainerTarget.querySelector("iframe")) return

    const iframe = document.createElement("iframe")
    iframe.src = `https://www.youtube.com/embed/${this.videoIdValue}?autoplay=1&rel=0`
    iframe.className = "w-full h-full"
    iframe.allow = "autoplay; encrypted-media"
    iframe.allowFullscreen = true
    this.videoContainerTarget.appendChild(iframe)
  }

  #removeVideo() {
    const iframe = this.videoContainerTarget.querySelector("iframe")
    if (iframe) iframe.remove()
  }
}
