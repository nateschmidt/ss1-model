import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { entityId: Number, defaultName: String }

  connect() {
    const override = sessionStorage.getItem(`entity-name-${this.entityIdValue}`)
    if (override) {
      this.element.textContent = override
    }
  }

  edit() {
    const current = this.element.textContent.trim()
    const input = document.createElement("input")
    input.type = "text"
    input.value = current
    input.className = "bg-transparent border border-accent/40 rounded px-1 py-0 text-sm font-medium text-white w-full outline-none focus:border-accent"
    input.style.fontFamily = "inherit"

    const commit = () => {
      const val = input.value.trim()
      const name = val || this.defaultNameValue
      this.element.textContent = name

      if (val && val !== this.defaultNameValue) {
        sessionStorage.setItem(`entity-name-${this.entityIdValue}`, name)
      } else {
        sessionStorage.removeItem(`entity-name-${this.entityIdValue}`)
      }
    }

    input.addEventListener("blur", commit)
    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") { e.preventDefault(); input.blur() }
      if (e.key === "Escape") { input.value = this.defaultNameValue; input.blur() }
    })

    this.element.textContent = ""
    this.element.appendChild(input)
    input.focus()
    input.select()
  }
}
