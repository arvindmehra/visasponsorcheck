import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["banner"]

  connect() {
    const consent = localStorage.getItem("cookie_consent")
    if (!consent) {
      this.bannerTarget.classList.remove("hidden")
    }
  }

  acceptAll() {
    localStorage.setItem("cookie_consent", "accepted")
    this.bannerTarget.classList.add("hidden")

    if (typeof gtag === "function") {
      gtag("consent", "update", {
        ad_storage: "granted",
        ad_user_data: "granted",
        ad_personalization: "granted",
        analytics_storage: "granted"
      })
    }
  }

  declineAll() {
    localStorage.setItem("cookie_consent", "declined")
    this.bannerTarget.classList.add("hidden")

    if (typeof gtag === "function") {
      gtag("consent", "update", {
        ad_storage: "denied",
        ad_user_data: "denied",
        ad_personalization: "denied",
        analytics_storage: "denied"
      })
    }
  }
}
