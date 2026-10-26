import { Controller } from "@hotwired/stimulus"

// "Give feedback": tells the message whether the app runs installed or in a browser tab.
export default class extends Controller {
  static targets = ["mode"]

  connect() {
    const installed = window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true
    this.modeTarget.value = installed ? "installed" : "browser"
  }
}
