Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Search routes
  get "search", to: "search#index"

  # Companies routes
  resources :companies, only: [:show]

  # Root path
  root "home#index"
end
