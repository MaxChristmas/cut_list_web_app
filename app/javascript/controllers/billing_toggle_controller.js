import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["monthlyBtn", "yearlyBtn", "oneShotBtn", "monthlyPrice", "yearlyPrice", "subscriptionPlans", "oneShotPlans", "billingCycleInput"]

  connect() {
    this.cycle = "monthly"
    this.updateUI()
  }

  selectMonthly() {
    this.cycle = "monthly"
    this.updateUI()
  }

  selectYearly() {
    this.cycle = "yearly"
    this.updateUI()
  }

  selectOneShot() {
    this.cycle = "one_shot"
    this.updateUI()
  }

  updateUI() {
    const isMonthly = this.cycle === "monthly"
    const isYearly = this.cycle === "yearly"
    const isOneShot = this.cycle === "one_shot"

    this.#toggleBtn(this.monthlyBtnTarget, isMonthly)
    this.#toggleBtn(this.yearlyBtnTarget, isYearly)
    this.#toggleBtn(this.oneShotBtnTarget, isOneShot)

    this.monthlyPriceTargets.forEach(el => el.classList.toggle("hidden", !isMonthly))
    this.yearlyPriceTargets.forEach(el => el.classList.toggle("hidden", !isYearly))

    this.subscriptionPlansTarget.classList.toggle("hidden", isOneShot)
    this.oneShotPlansTarget.classList.toggle("hidden", !isOneShot)

    this.billingCycleInputTargets.forEach(input => input.value = this.cycle)
  }

  #toggleBtn(btn, active) {
    btn.classList.toggle("bg-blue-600", active)
    btn.classList.toggle("text-white", active)
    btn.classList.toggle("bg-transparent", !active)
    btn.classList.toggle("text-gray-400", !active)
  }
}
