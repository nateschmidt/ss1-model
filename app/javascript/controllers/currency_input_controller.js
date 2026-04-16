import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "hidden"]

  connect() {
    this.format()
  }

  format() {
    const raw = this.displayTarget.value.replace(/[^0-9]/g, "")
    const num = parseInt(raw, 10) || 0
    this.hiddenTarget.value = num
    this.displayTarget.value = num.toLocaleString("en-US")
  }

  submit() {
    this.format()
    this.element.closest("form").requestSubmit()
  }
}
