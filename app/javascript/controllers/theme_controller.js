import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sunIcon", "moonIcon"]

  connect() {
    const saved = localStorage.getItem("ss1-theme")
    if (saved === "light") {
      this.setLight()
    } else {
      this.setDark()
    }
  }

  toggle() {
    if (document.documentElement.dataset.theme === "light") {
      this.setDark()
      localStorage.setItem("ss1-theme", "dark")
    } else {
      this.setLight()
      localStorage.setItem("ss1-theme", "light")
    }
  }

  setLight() {
    document.documentElement.dataset.theme = "light"
    this.sunIconTarget.classList.add("hidden")
    this.moonIconTarget.classList.remove("hidden")
  }

  setDark() {
    document.documentElement.dataset.theme = "dark"
    this.moonIconTarget.classList.add("hidden")
    this.sunIconTarget.classList.remove("hidden")
  }
}
