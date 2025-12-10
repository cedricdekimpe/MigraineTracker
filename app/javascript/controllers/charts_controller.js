import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["timeChart", "dayChart", "medicationChart"]
  static values = {
    monthlyData: Array,
    dayOfWeekData: Array,
    medicationData: Array
  }

  connect() {
    this.loadChartJS().then(() => {
      this.initializeCharts()
    }).catch((error) => {
      console.error('Failed to load Chart.js:', error)
    })
  }

  disconnect() {
    this.destroyCharts()
  }

  loadChartJS() {
    return new Promise((resolve, reject) => {
      if (typeof Chart !== 'undefined') {
        resolve()
        return
      }

      const script = document.createElement('script')
      script.src = 'https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js'
      script.onload = resolve
      script.onerror = reject
      document.head.appendChild(script)
    })
  }

  initializeCharts() {
    this.destroyCharts()

    // Migraines Over Time Chart
    if (this.hasTimeChartTarget) {
      this.timeChart = new Chart(this.timeChartTarget, {
        type: 'line',
        data: {
          labels: this.monthlyDataValue.map(d => d[0]),
          datasets: [{
            label: 'Number of Migraines',
            data: this.monthlyDataValue.map(d => d[1]),
            borderColor: 'rgb(16, 185, 129)',
            backgroundColor: 'rgba(16, 185, 129, 0.1)',
            tension: 0.3,
            fill: true
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              display: false
            }
          },
          scales: {
            y: {
              beginAtZero: true,
              ticks: {
                stepSize: 1
              }
            }
          }
        }
      })
    }

    // Day of Week Chart
    if (this.hasDayChartTarget) {
      this.dayChart = new Chart(this.dayChartTarget, {
        type: 'bar',
        data: {
          labels: this.dayOfWeekDataValue.map(d => d[0]),
          datasets: [{
            label: 'Number of Migraines',
            data: this.dayOfWeekDataValue.map(d => d[1]),
            backgroundColor: [
              'rgba(239, 68, 68, 0.8)',
              'rgba(249, 115, 22, 0.8)',
              'rgba(234, 179, 8, 0.8)',
              'rgba(16, 185, 129, 0.8)',
              'rgba(59, 130, 246, 0.8)',
              'rgba(139, 92, 246, 0.8)',
              'rgba(236, 72, 153, 0.8)'
            ]
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              display: false
            }
          },
          scales: {
            y: {
              beginAtZero: true,
              ticks: {
                stepSize: 1
              }
            }
          }
        }
      })
    }

    // Medication Chart
    if (this.hasMedicationChartTarget && this.medicationDataValue.length > 0) {
      this.medicationChart = new Chart(this.medicationChartTarget, {
        type: 'doughnut',
        data: {
          labels: this.medicationDataValue.map(d => d[0]),
          datasets: [{
            data: this.medicationDataValue.map(d => d[1]),
            backgroundColor: [
              'rgba(16, 185, 129, 0.8)',
              'rgba(59, 130, 246, 0.8)',
              'rgba(249, 115, 22, 0.8)',
              'rgba(139, 92, 246, 0.8)',
              'rgba(236, 72, 153, 0.8)',
              'rgba(234, 179, 8, 0.8)'
            ]
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              position: 'bottom'
            }
          }
        }
      })
    }
  }

  destroyCharts() {
    if (this.timeChart) {
      this.timeChart.destroy()
      this.timeChart = null
    }
    if (this.dayChart) {
      this.dayChart.destroy()
      this.dayChart = null
    }
    if (this.medicationChart) {
      this.medicationChart.destroy()
      this.medicationChart = null
    }
  }
}
