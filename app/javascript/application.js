// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import { Turbo } from "@hotwired/turbo-rails"

// Disable Turbo Drive globally — we only use Turbo Streams for real-time broadcasts
Turbo.session.drive = false

import "./controllers"

// Register service worker for PWA support
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker.js", { scope: "/" })
}
