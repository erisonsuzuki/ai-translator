import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["result", "state"]

  sourceChanged() {
    if (!this.hasResultTarget) return
    if (!this.resultTarget.querySelector(".result")) return

    this.resultTarget.innerHTML = '<p class="result-placeholder">Result cleared because the source text changed. Click "Translate" to refresh.</p>'

    if (this.hasStateTarget) {
      this.stateTarget.textContent = ""
      requestAnimationFrame(() => {
        this.stateTarget.textContent = "Previous translation result cleared because source text changed."
      })
    }
  }
}
