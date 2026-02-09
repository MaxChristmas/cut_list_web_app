Rails.application.routes.draw do
  get "projects/index"
  get "projects/show"
  get "projects/new"
  get "projects/create"
  get "projects/edit"
  get "projects/update"
  
  devise_for :users
  get "up" => "rails/health#show", as: :rails_health_check
  
  # root "posts#index"
end
