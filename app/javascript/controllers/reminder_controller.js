import { Controller } from "@hotwired/stimulus"

// The daily check-in reminder in the account. Turning it on first asks this device for notifications and
// gives the server where to send them; the form is saved only once that worked. It also says when this
// device does not get the reminder that is on, and why: blocked, iPhone not installed, no support.
export default class extends Controller {
  static targets = ["form", "enabled", "zone", "message", "here", "texts"]
  static values = { key: String, url: String, on: Boolean }

  async connect() {
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (zone) this.zoneTarget.value = zone

    if (this.onValue && !(await this.subscribed())) this.explain(this.problem() || "device", !this.problem())
  }

  async save(event) {
    if (this.saving) return
    event.preventDefault()

    if (this.enabledTarget.checked) {
      if (!(await this.subscribe())) return
    } else {
      await this.unsubscribe()
    }
    this.saving = true
    this.formTarget.requestSubmit()
  }

  async receiveHere() {
    if (await this.subscribe()) this.explain("ready", false)
  }

  async subscribe() {
    const problem = this.problem()
    if (problem) return this.explain(problem, false)

    try {
      if ((await Notification.requestPermission()) !== "granted") return this.explain("denied", false)

      const registration = await navigator.serviceWorker.ready
      const subscription = (await registration.pushManager.getSubscription()) ||
        (await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: this.applicationServerKey }))
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" },
        body: JSON.stringify({ subscription: subscription.toJSON() })
      })
      return response.ok || this.explain("failed", false)
    } catch {
      return this.explain("failed", false)
    }
  }

  // Turned off: the server forgets every device; this one also stops listening
  async unsubscribe() {
    try {
      const registration = await navigator.serviceWorker?.getRegistration()
      const subscription = await registration?.pushManager?.getSubscription()
      await subscription?.unsubscribe()
    } catch {
      // The server side is what matters: nothing is sent once the reminder is off
    }
  }

  async subscribed() {
    if (this.problem() || Notification.permission !== "granted") return false
    const registration = await navigator.serviceWorker.getRegistration()
    return Boolean(await registration?.pushManager.getSubscription())
  }

  problem() {
    if (this.ios && !this.installed) return "ios"
    if (!window.isSecureContext || !("serviceWorker" in navigator) || !("PushManager" in window) || !("Notification" in window)) return "unsupported"
    if (Notification.permission === "denied") return "denied"
    return null
  }

  // Shows a message (and the "Get it here" button when it can help). Returns false for the callers.
  explain(key, offerHere) {
    this.messageTarget.textContent = this.textsTarget.content.querySelector(`[data-key="${key}"]`).textContent
    this.messageTarget.hidden = false
    this.hereTarget.hidden = !offerHere
    return false
  }

  get applicationServerKey() {
    const base64 = (this.keyValue + "=".repeat((4 - (this.keyValue.length % 4)) % 4)).replace(/-/g, "+").replace(/_/g, "/")
    return Uint8Array.from(atob(base64), (character) => character.charCodeAt(0))
  }

  get installed() {
    return window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true
  }

  get ios() {
    return /iphone|ipad|ipod/i.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1)
  }
}
