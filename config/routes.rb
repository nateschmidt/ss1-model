Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "cap_table#show"

  patch "variables/:id", to: "cap_table#update_variable", as: :update_variable
  patch "entities/:id", to: "cap_table#update_entity", as: :update_entity
  post "entities/:id/increment_finders_fee", to: "cap_table#increment_finders_fee", as: :increment_finders_fee
  post "entities/:id/decrement_finders_fee", to: "cap_table#decrement_finders_fee", as: :decrement_finders_fee
end
