import { Controller } from "@hotwired/stimulus"

// The "get started" card: the install step is not offered when the app already runs installed.
export default class extends Controller {
  static targets = ["install"]

  connect() {
    const installed = window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true
    if (installed) this.installTarget.hidden = true
  }
}
