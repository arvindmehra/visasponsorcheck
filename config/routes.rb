Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Search routes
  get "search", to: "search#index"

  # FAQ + Static pages
  get "faq", to: "pages#faq", as: :faq

  # Sponsor directory — city, route/type, rating, revoked
  get "sponsors",                          to: "sponsors#index",   as: :sponsors
  get "sponsors/a-rated",                  to: "sponsors#a_rated", as: :a_rated_sponsors
  get "sponsors/revoked",                  to: "sponsors#revoked", as: :revoked_sponsors
  get "sponsors/city/:city",               to: "sponsors#city",    as: :city_sponsors
  get "sponsors/route/:route",             to: "sponsors#route",   as: :route_sponsors

  # Company pages — keyword-rich /sponsor/:slug URL
  get "sponsor/:id",                       to: "companies#show",   as: :company

  # 301 redirect from old /companies/:id to /sponsor/:id
  get "companies/:id",                     to: redirect("/sponsor/%{id}"), as: :old_company

  # Root path
  root "home#index"
end
