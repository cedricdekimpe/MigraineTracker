import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "confirmationInput", "passwordInput", "submitButton", "dataCount"]
  static values = {
    confirmationPhrase: String
  }

  connect() {
    // Ensure modal is hidden on connect
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden")
    }
  }

  open(event) {
    event.preventDefault()
    this.modalTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    
    // Reset form state
    if (this.hasConfirmationInputTarget) {
      this.confirmationInputTarget.value = ""
    }
    if (this.hasPasswordInputTarget) {
      this.passwordInputTarget.value = ""
    }
    this.updateSubmitButton()
  }

  close(event) {
    if (event) {
      event.preventDefault()
    }
    this.modalTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  closeBackground(event) {
    // Only close if clicking the background overlay, not the modal content
    if (event.target === this.modalTarget) {
      this.close(event)
    }
  }

  validateConfirmation() {
    this.updateSubmitButton()
  }

  updateSubmitButton() {
    const confirmationValue = this.hasConfirmationInputTarget ? this.confirmationInputTarget.value.trim() : ""
    const passwordValue = this.hasPasswordInputTarget ? this.passwordInputTarget.value : ""
    const phraseMatches = confirmationValue === this.confirmationPhraseValue
    const hasPassword = passwordValue.length > 0

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = !(phraseMatches && hasPassword)
      
      if (phraseMatches && hasPassword) {
        this.submitButtonTarget.classList.remove("opacity-50", "cursor-not-allowed")
        this.submitButtonTarget.classList.add("hover:bg-red-700")
      } else {
        this.submitButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
        this.submitButtonTarget.classList.remove("hover:bg-red-700")
      }
    }
  }

  // Handle escape key to close modal
  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close(event)
    }
  }
}
