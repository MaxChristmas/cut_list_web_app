import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["monthlyBtn", "yearlyBtn", "monthlyPrice", "yearlyPrice", "billingCycleInput"]

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

  updateUI() {
    const isMonthly = this.cycle === "monthly"

    this.monthlyBtnTarget.classList.toggle("bg-blue-600", isMonthly)
    this.monthlyBtnTarget.classList.toggle("text-white", isMonthly)
    this.monthlyBtnTarget.classList.toggle("bg-transparent", !isMonthly)
    this.monthlyBtnTarget.classList.toggle("text-gray-400", !isMonthly)

    this.yearlyBtnTarget.classList.toggle("bg-blue-600", !isMonthly)
    this.yearlyBtnTarget.classList.toggle("text-white", !isMonthly)
    this.yearlyBtnTarget.classList.toggle("bg-transparent", isMonthly)
    this.yearlyBtnTarget.classList.toggle("text-gray-400", isMonthly)

    this.monthlyPriceTargets.forEach(el => el.classList.toggle("hidden", !isMonthly))
    this.yearlyPriceTargets.forEach(el => el.classList.toggle("hidden", isMonthly))
    this.billingCycleInputTargets.forEach(input => input.value = this.cycle)
  }
}
