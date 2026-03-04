import { Controller } from "@hotwired/stimulus"
import { Chart, DoughnutController, ArcElement, Tooltip, Legend } from "chart.js"

Chart.register(DoughnutController, ArcElement, Tooltip, Legend)

export default class extends Controller {
  static values = {
    labels: Array,
    data: Array,
    colors: Array
  }

  connect() {
    this.chart = new Chart(this.element, {
      type: "doughnut",
      data: {
        labels: this.labelsValue,
        datasets: [{
          data: this.dataValue,
          backgroundColor: this.colorsValue,
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "bottom",
            labels: { padding: 16, usePointStyle: true, pointStyle: "circle" }
          },
          tooltip: {
            callbacks: {
              label: (ctx) => {
                const total = ctx.dataset.data.reduce((a, b) => a + b, 0)
                const pct = total > 0 ? ((ctx.raw / total) * 100).toFixed(1) : 0
                return `${ctx.label}: ${ctx.raw} (${pct}%)`
              }
            }
          }
        }
      }
    })
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }
}
