import { Controller } from "@hotwired/stimulus"

// Three-way theme switch: "auto" follows the system, "light" pins Papier, "night" pins Nuit.
// The choice is kept in localStorage; an inline script in the layout applies it before first paint.
export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.render()
  }

  set(event) {
    const value = event.params.value
    try {
      if (value === "auto") localStorage.removeItem("theme")
      else localStorage.setItem("theme", value)
    } catch (error) {
      // storage can be blocked (private window): the choice then lasts for this page only
    }

    if (value === "auto") delete document.documentElement.dataset.theme
    else document.documentElement.dataset.theme = value
    this.render()
  }

  render() {
    const current = document.documentElement.dataset.theme || "auto"
    this.buttonTargets.forEach((button) => {
      button.setAttribute("aria-pressed", String(button.dataset.themeValueParam === current))
    })
  }
}
