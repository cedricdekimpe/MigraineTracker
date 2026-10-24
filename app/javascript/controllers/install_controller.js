import { Controller } from "@hotwired/stimulus"

// "Install the app" in the account. Hidden when the app already runs installed, or when the browser
// offers no way to install it. Chrome (Android, computer): a button that opens Chrome's own prompt,
// kept aside in application.js. iPhone and iPad: the Share › "Add to Home Screen" hint.
export default class extends Controller {
  static targets = ["button", "ios"]

  connect() {
    if (this.installed) return

    this.offer = () => this.show()
    document.addEventListener("pwa:installable", this.offer)
    if (window.deferredInstallPrompt) this.show()
    else if (this.ios) this.show({ ios: true })
  }

  disconnect() {
    if (this.offer) document.removeEventListener("pwa:installable", this.offer)
  }

  async install() {
    const prompt = window.deferredInstallPrompt
    if (!prompt) return

    window.deferredInstallPrompt = null
    prompt.prompt()
    await prompt.userChoice
    this.element.hidden = true
  }

  show({ ios = false } = {}) {
    this.buttonTarget.hidden = ios
    this.iosTarget.hidden = !ios
    this.element.hidden = false
  }

  get installed() {
    return window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true
  }

  get ios() {
    return /iphone|ipad|ipod/i.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1)
  }
}
