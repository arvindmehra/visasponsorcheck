document.addEventListener("turbo:load", () => {
  // Fire page_view on every page transition (including initial load)
  if (typeof gtag === "function") {
    gtag("event", "page_view", {
      page_location: window.location.href,
      page_path: window.location.pathname,
      page_title: document.title,
    });
  }

  // Update consent status based on local storage settings
  const consent = localStorage.getItem("cookie_consent");
  if (consent === "accepted" && typeof gtag === "function") {
    gtag("consent", "update", {
      ad_storage: "granted",
      ad_user_data: "granted",
      ad_personalization: "granted",
      analytics_storage: "granted"
    });
  } else if (consent === "declined" && typeof gtag === "function") {
    gtag("consent", "update", {
      ad_storage: "denied",
      ad_user_data: "denied",
      ad_personalization: "denied",
      analytics_storage: "denied"
    });
  }
});
