Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "cap_table#show"

  # Cap Table
  patch "variables/:id", to: "cap_table#update_variable", as: :update_variable
  patch "entities/:id", to: "cap_table#update_entity", as: :update_entity
  post "entities/:id/increment_finders_fee", to: "cap_table#increment_finders_fee", as: :increment_finders_fee
  post "entities/:id/decrement_finders_fee", to: "cap_table#decrement_finders_fee", as: :decrement_finders_fee

  # Scenarios
  get "scenarios", to: "scenarios#show", as: :scenarios
  post "scenarios/single_run", to: "scenarios#single_run", as: :single_run_scenarios
  post "scenarios/simulate", to: "scenarios#simulate", as: :simulate_scenarios
end
