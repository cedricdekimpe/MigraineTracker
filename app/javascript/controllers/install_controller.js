import { Controller } from "@hotwired/stimulus"

// "Install the app" in the account. Hidden when the app already runs installed. Otherwise it says
// something useful: a button when the browser offers its install prompt (kept aside in application.js),
// the Share hint on iPhone and iPad, and for any other browser where to find it in its menu.
export default class extends Controller {
  static targets = ["button", "ios", "menu"]

  connect() {
    if (this.installed) return

    this.offer = () => this.show("button")
    document.addEventListener("pwa:installable", this.offer)
    if (window.deferredInstallPrompt) this.show("button")
    else this.show(this.ios ? "ios" : "menu")
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

  show(which) {
    this.buttonTarget.hidden = which !== "button"
    this.iosTarget.hidden = which !== "ios"
    this.menuTarget.hidden = which !== "menu"
    this.element.hidden = false
  }

  get installed() {
    return window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true
  }

  get ios() {
    return /iphone|ipad|ipod/i.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1)
  }
}
