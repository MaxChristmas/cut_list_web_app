import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "cookie_consent"
const EXPIRY_DAYS = 395 // ~13 months (CNIL recommendation)

export default class extends Controller {
  static targets = ["dialog", "initialView", "settingsView", "analyticsToggle"]

  #boundOpenSettings = null

  connect() {
    this.#boundOpenSettings = () => this.openSettings()
    document.addEventListener("cookie-consent:open", this.#boundOpenSettings)

    const consent = this.#getConsent()
    if (!consent || this.#isExpired(consent)) {
      this.dialogTarget.showModal()
    } else if (consent.analytics) {
      this.#loadAnalytics()
    }
  }

  disconnect() {
    document.removeEventListener("cookie-consent:open", this.#boundOpenSettings)
  }

  acceptAll() {
    this.#saveConsent({ analytics: true })
    this.#loadAnalytics()
    this.dialogTarget.close()
  }

  declineAll() {
    this.#saveConsent({ analytics: false })
    this.dialogTarget.close()
  }

  customize() {
    this.initialViewTarget.classList.add("hidden")
    this.settingsViewTarget.classList.remove("hidden")
  }

  savePreferences() {
    const analytics = this.analyticsToggleTarget.checked
    this.#saveConsent({ analytics })
    if (analytics) this.#loadAnalytics()
    this.dialogTarget.close()
    this.#resetView()
  }

  openSettings() {
    const consent = this.#getConsent()
    if (consent) {
      this.analyticsToggleTarget.checked = consent.analytics || false
    }
    this.initialViewTarget.classList.add("hidden")
    this.settingsViewTarget.classList.remove("hidden")
    this.dialogTarget.showModal()
  }

  // Private

  #getConsent() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY)
      return raw ? JSON.parse(raw) : null
    } catch {
      return null
    }
  }

  #saveConsent({ analytics }) {
    const consent = {
      analytics,
      timestamp: Date.now()
    }
    localStorage.setItem(STORAGE_KEY, JSON.stringify(consent))
  }

  #isExpired(consent) {
    if (!consent.timestamp) return true
    const expiryMs = EXPIRY_DAYS * 24 * 60 * 60 * 1000
    return Date.now() - consent.timestamp > expiryMs
  }

  #loadAnalytics() {
    if (document.getElementById("ga-script")) return
    const meta = document.head.querySelector("meta[name='ga-id']")
    const id = meta?.content
    if (!id) return

    const script = document.createElement("script")
    script.id = "ga-script"
    script.async = true
    script.src = `https://www.googletagmanager.com/gtag/js?id=${id}`
    document.head.appendChild(script)

    window.dataLayer = window.dataLayer || []
    window.gtag = function () { window.dataLayer.push(arguments) }
    window.gtag("js", new Date())
    window.gtag("config", id, { anonymize_ip: true })
  }

  #resetView() {
    this.initialViewTarget.classList.remove("hidden")
    this.settingsViewTarget.classList.add("hidden")
  }
}
