import { Controller } from "@hotwired/stimulus"

// Sends the crises noted on the "no connection" page (kept in localStorage) as soon as a page of the
// app opens online, or the network comes back. The phone forgets each crisis once the server has
// handled it (saved, already in the journal, or unusable); on failure it keeps them for next time.
const KEY = "pendingCrises"

export default class extends Controller {
  connect() {
    this.send = () => this.flush()
    window.addEventListener("online", this.send)
    this.flush()
  }

  disconnect() {
    window.removeEventListener("online", this.send)
  }

  async flush() {
    const pending = this.pending()
    if (pending.length === 0 || this.sending) return

    this.sending = true
    try {
      // In the page's language: it picks the language of the confirmation and of the next page
      const locale = document.documentElement.lang === "en" ? "en" : "fr"
      const response = await fetch(`/${locale}/now/offline`, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        },
        body: JSON.stringify({ crises: pending })
      })
      if (!response.ok) return

      const { handled, saved, location } = await response.json()
      const left = this.pending().filter((crisis) => !handled.includes(crisis.id))
      if (left.length > 0) localStorage.setItem(KEY, JSON.stringify(left))
      else localStorage.removeItem(KEY)

      if (saved > 0) window.Turbo.visit(location || window.location.href, { action: "replace" })
    } catch (error) {
      // still no network, or storage blocked: next time
    } finally {
      this.sending = false
    }
  }

  pending() {
    try {
      const list = JSON.parse(localStorage.getItem(KEY) || "[]")
      return Array.isArray(list) ? list : []
    } catch (error) {
      return []
    }
  }
}
