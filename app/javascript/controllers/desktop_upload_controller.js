import { Controller } from "@hotwired/stimulus"

const MAX_SIDE = 4096
const MAX_FILE_SIZE = 4.5 * 1024 * 1024
const JPEG_QUALITY = 0.85

export default class extends Controller {
  static targets = ["fileInput", "button", "spinner"]
  static values = { token: String }

  openFile() {
    this.fileInputTarget.click()
  }

  fileSelected() {
    if (this.fileInputTarget.files.length === 0) return

    const file = this.fileInputTarget.files[0]

    this.buttonTarget.classList.add("hidden")
    this.spinnerTarget.classList.remove("hidden")
    this.spinnerTarget.style.display = "flex"

    if (file.size <= MAX_FILE_SIZE) {
      this.#upload(file)
    } else {
      this.#resizeAndUpload(file)
    }
  }

  // Private

  #resizeAndUpload(file) {
    const reader = new FileReader()

    reader.onload = (event) => {
      const img = new Image()

      img.onload = () => {
        this.#resizeToBlob(img).then((blob) => this.#upload(blob))
      }

      img.src = event.target.result
    }

    reader.readAsDataURL(file)
  }

  #resizeToBlob(img) {
    const longest = Math.max(img.naturalWidth, img.naturalHeight)
    let width = img.naturalWidth
    let height = img.naturalHeight

    if (longest > MAX_SIDE) {
      const scale = MAX_SIDE / longest
      width = Math.round(width * scale)
      height = Math.round(height * scale)
    }

    const canvas = document.createElement("canvas")
    canvas.width = width
    canvas.height = height

    const ctx = canvas.getContext("2d")
    ctx.drawImage(img, 0, 0, width, height)

    return new Promise((resolve) => {
      canvas.toBlob((blob) => resolve(blob), "image/jpeg", JPEG_QUALITY)
    })
  }

  async #upload(file) {
    const formData = new FormData()
    formData.append("photo", file, file.name || "photo.jpg")

    try {
      const response = await fetch(`/scan/${this.tokenValue}/upload`, {
        method: "POST",
        body: formData,
      })

      if (!response.ok) {
        this.#showError()
      }
      // Success — the Turbo Stream broadcast will update the desktop UI automatically
    } catch {
      this.#showError()
    }
  }

  #showError() {
    this.spinnerTarget.classList.add("hidden")
    this.buttonTarget.classList.remove("hidden")
  }
}
