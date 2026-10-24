// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Installable app. The service worker needs a secure origin (HTTPS, or localhost).
if ("serviceWorker" in navigator && window.isSecureContext) {
  navigator.serviceWorker.register("/service-worker.js").catch(() => {})
}

// Chrome's own install banner could pop up anywhere, the crisis screen included: it is held back and
// offered only by the "Install" button of the account (install controller).
window.addEventListener("beforeinstallprompt", (event) => {
  event.preventDefault()
  window.deferredInstallPrompt = event
  document.dispatchEvent(new Event("pwa:installable"))
})
window.addEventListener("appinstalled", () => { window.deferredInstallPrompt = null })
