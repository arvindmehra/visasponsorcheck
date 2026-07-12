Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Search routes
  get "search", to: "search#index"

  # FAQ + Static pages
  get "faq", to: "pages#faq", as: :faq
  get "uk-visa-sponsorship-list", to: "pages#sponsorship_list_guide", as: :sponsorship_list_guide

  # Sponsor directory — city, route/type, rating, revoked
  get "sponsors",                          to: "sponsors#index",   as: :sponsors
  get "sponsors/locations",                to: "sponsors#locations", as: :locations_sponsors
  get "sponsors/a-rated",                  to: "sponsors#a_rated", as: :a_rated_sponsors
  get "sponsors/revoked",                  to: "sponsors#revoked", as: :revoked_sponsors
  get "sponsors/city/:city",               to: "sponsors#city",    as: :city_sponsors
  get "sponsors/visa-routes",               to: "sponsors#routes",  as: :visa_routes_sponsors
  # "Tier 2" was the pre-Dec-2021 name for the Skilled Worker route — people
  # still search/link with the old term. Redirect rather than duplicate the
  # page, so ranking signal consolidates on the one canonical URL.
  get "sponsors/visa-route/tier-2",         to: redirect("/sponsors/visa-route/skilled-worker"), as: :tier_2_sponsors_redirect
  get "sponsors/visa-route/:route",         to: "sponsors#route",   as: :visa_route_sponsors
  get "sponsors/sectors",                  to: "sponsors#sectors", as: :sectors_sponsors
  get "sponsors/sector/:sector",           to: "sponsors#sector",  as: :sector_sponsors
  get "sponsors/recent/:type",             to: "sponsors#recent",  as: :recent_sponsors

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
