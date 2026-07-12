Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Search routes
  get "search", to: "search#index"

  # FAQ + Static pages
  get "faq", to: "pages#faq", as: :faq

  # Sponsor directory — city, route/type, rating, revoked
  get "sponsors",                          to: "sponsors#index",   as: :sponsors
  get "sponsors/locations",                to: "sponsors#locations", as: :locations_sponsors
  get "sponsors/a-rated",                  to: "sponsors#a_rated", as: :a_rated_sponsors
  get "sponsors/revoked",                  to: "sponsors#revoked", as: :revoked_sponsors
  get "sponsors/city/:city",               to: "sponsors#city",    as: :city_sponsors
  get "sponsors/route/:route",             to: "sponsors#route",   as: :route_sponsors

  # Company pages — keyword-rich /sponsor/:slug URL
  get "sponsor/:id",                       to: "companies#show",   as: :company
  get "sponsor/:id/enrich",                to: "companies#enrich", as: :enrich_company

  # 301 redirect from old /companies/:id to /sponsor/:id
  get "companies/:id",                     to: redirect("/sponsor/%{id}"), as: :old_company

  # Sitemap redirects to volume-backed path
  get "sitemap.xml", to: redirect("/sitemaps/sitemap.xml.gz")
  get "sitemap.xml.gz", to: redirect("/sitemaps/sitemap.xml.gz")

  # Jobs UI Dashboard
  mount MissionControl::Jobs::Engine, at: "/jobs"

  mount PgHero::Engine, at: "/pghero"

  # Root path
  root "home#index"
end
