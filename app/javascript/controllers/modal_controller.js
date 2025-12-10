import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
export default class extends Controller {
  static targets = ["overlay", "dialog"]

  connect() {
    // Prevent body scroll when modal is open
    document.body.style.overflow = "hidden"
    
    // Add escape key listener
    this.escapeHandler = this.handleEscape.bind(this)
    document.addEventListener("keydown", this.escapeHandler)
  }

  disconnect() {
    // Re-enable body scroll
    document.body.style.overflow = ""
    
    // Remove escape key listener
    document.removeEventListener("keydown", this.escapeHandler)
  }

  close(event) {
    if (event) {
      event.preventDefault()
    }
    
    // Remove the modal element
    this.element.remove()
  }

  closeBackground(event) {
    if (event.target === this.overlayTarget) {
      this.close(event)
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  handleEscape(event) {
    if (event.key === "Escape") {
      this.close(event)
    }
  }
}
