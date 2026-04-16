import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  toggle(event) {
    event.stopPropagation()
    const isOpen = !this.modalTarget.classList.contains("hidden")
    this.closeAll()
    if (!isOpen) {
      this.modalTarget.classList.remove("hidden")
      // Close on outside click
      this._outsideClick = (e) => {
        if (!this.element.contains(e.target)) this.close()
      }
      document.addEventListener("click", this._outsideClick)
    }
  }

  close() {
    this.modalTarget.classList.add("hidden")
    if (this._outsideClick) {
      document.removeEventListener("click", this._outsideClick)
      this._outsideClick = null
    }
  }

  closeAll() {
    document.querySelectorAll("[data-tooltip-target='modal']").forEach(el => {
      el.classList.add("hidden")
    })
  }
}
