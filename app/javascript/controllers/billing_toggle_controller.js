import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["monthlyBtn", "yearlyBtn", "monthlyPrice", "yearlyPrice", "billingCycleInput"]

  connect() {
    this.cycle = "monthly"
    this.updateUI()
  }

  selectMonthly() {
    this.cycle = "monthly"
    if (window.posthog) posthog.capture('pricing_toggle', { plan: this.cycle })
    this.updateUI()
  }

  selectYearly() {
    this.cycle = "yearly"
    if (window.posthog) posthog.capture('pricing_toggle', { plan: this.cycle })
    this.updateUI()
  }

  updateUI() {
    const isMonthly = this.cycle === "monthly"

    this.#toggleBtn(this.monthlyBtnTarget, isMonthly)
    this.#toggleBtn(this.yearlyBtnTarget, !isMonthly)

    this.monthlyPriceTargets.forEach(el => el.classList.toggle("hidden", !isMonthly))
    this.yearlyPriceTargets.forEach(el => el.classList.toggle("hidden", isMonthly))

    this.billingCycleInputTargets.forEach(input => input.value = this.cycle)
  }

  #toggleBtn(btn, active) {
    btn.classList.toggle("bg-blue-600", active)
    btn.classList.toggle("text-white", active)
    btn.classList.toggle("bg-transparent", !active)
    btn.classList.toggle("text-gray-400", !active)
  }
}
