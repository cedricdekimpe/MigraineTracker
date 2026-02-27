import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "dialog"]

  connect() {
    // Add escape key listener
    this.boundCloseOnEscape = this.closeOnEscape.bind(this)
    document.addEventListener("keydown", this.boundCloseOnEscape)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundCloseOnEscape)
  }

  close(event) {
    if (event) {
      event.preventDefault()
    }
    this.element.remove()
    document.body.classList.remove("overflow-hidden")
  }

  closeBackground(event) {
    // Only close if clicking the background overlay, not the modal content
    if (this.hasOverlayTarget && event.target === this.overlayTarget) {
      this.close(event)
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close(event)
    }
  }
}
