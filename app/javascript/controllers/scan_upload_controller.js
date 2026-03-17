import { Controller } from "@hotwired/stimulus"

const MAX_SIDE = 4096
const MAX_FILE_SIZE = 4.5 * 1024 * 1024 // 4.5 MB to stay under Anthropic's 5 MB limit
const JPEG_QUALITY = 0.85

export default class extends Controller {
  static targets = ["form", "fileInput", "cameraButton", "spinner", "error"]

  openCamera() {
    this.fileInputTarget.click()
  }

  fileSelected() {
    if (this.fileInputTarget.files.length === 0) return

    const file = this.fileInputTarget.files[0]

    this.cameraButtonTarget.classList.add("hidden")
    this.spinnerTarget.classList.remove("hidden")
    this.errorTarget.classList.add("hidden")

    // Only resize if the file is too large or too many pixels
    if (file.size <= MAX_FILE_SIZE) {
      this.#upload(file)
    } else {
      this.#resizeAndUpload(file)
    }
  }

  submit(event) {
    event.preventDefault()
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
    const { width, height } = this.#scaledDimensions(img.naturalWidth, img.naturalHeight)

    const canvas = document.createElement("canvas")
    canvas.width = width
    canvas.height = height

    const ctx = canvas.getContext("2d")
    ctx.drawImage(img, 0, 0, width, height)

    return new Promise((resolve) => {
      canvas.toBlob((blob) => resolve(blob), "image/jpeg", JPEG_QUALITY)
    })
  }

  #scaledDimensions(originalWidth, originalHeight) {
    const longest = Math.max(originalWidth, originalHeight)

    if (longest <= MAX_SIDE) {
      return { width: originalWidth, height: originalHeight }
    }

    const scale = MAX_SIDE / longest
    return {
      width: Math.round(originalWidth * scale),
      height: Math.round(originalHeight * scale),
    }
  }

  async #upload(file) {
    const formData = new FormData()
    const name = file.name || "photo.jpg"
    formData.append("photo", file, name)

    try {
      const response = await fetch(this.formTarget.action, {
        method: "POST",
        body: formData,
      })

      const html = await response.text()
      document.open()
      document.write(html)
      document.close()
    } catch {
      this.#showError()
    }
  }

  #showError() {
    this.spinnerTarget.classList.add("hidden")
    this.cameraButtonTarget.classList.remove("hidden")
    this.errorTarget.classList.remove("hidden")
    this.errorTarget.textContent = "Upload failed. Please try again."
  }
}
