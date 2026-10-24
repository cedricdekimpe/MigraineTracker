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
    this.syncBrowserBar(current)
  }

  // The phone's status bar (and the installed app's title bar) takes the colour of the pinned theme;
  // in "auto" each meta keeps its own media query. The crisis screen has a single Night meta, untouched.
  syncBrowserBar(current) {
    const metas = document.querySelectorAll('meta[name="theme-color"][data-theme-color]')
    metas.forEach((meta) => {
      meta.dataset.media ||= meta.getAttribute("media")
      if (current === "auto") {
        meta.setAttribute("media", meta.dataset.media)
      } else if (meta.dataset.themeColor === current) {
        meta.removeAttribute("media")
      } else {
        meta.setAttribute("media", "not all")
      }
    })
  }
}
