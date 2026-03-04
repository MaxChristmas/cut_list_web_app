import { Controller } from "@hotwired/stimulus"
import { Chart, BarController, BarElement, CategoryScale, LinearScale, Tooltip, Legend } from "chart.js"

Chart.register(BarController, BarElement, CategoryScale, LinearScale, Tooltip, Legend)

export default class extends Controller {
  static values = {
    labels: Array,
    data: Array
  }

  connect() {
    this.chart = new Chart(this.element, {
      type: "bar",
      data: {
        labels: this.labelsValue,
        datasets: [{
          label: "Nouveaux utilisateurs",
          data: this.dataValue,
          backgroundColor: "rgba(59, 130, 246, 0.7)",
          borderColor: "rgb(59, 130, 246)",
          borderWidth: 1,
          borderRadius: 4
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false }
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: { stepSize: 1, precision: 0 }
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
