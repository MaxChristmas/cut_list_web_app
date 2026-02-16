import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    if (!localStorage.getItem("cookie_consent")) {
      this.dialogTarget.showModal()
    }
  }

  accept() {
    localStorage.setItem("cookie_consent", "accepted")
    this.dialogTarget.close()
  }

  decline() {
    localStorage.setItem("cookie_consent", "declined")
    this.dialogTarget.close()
  }
}
