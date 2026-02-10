Rails.application.routes.draw do
 resources :projects
  
  devise_for :users
  get "up" => "rails/health#show", as: :rails_health_check
  
  root "projects#index"
end

