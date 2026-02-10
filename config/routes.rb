Rails.application.routes.draw do
  resources :projects

  devise_for :users

  patch "locale", to: "application#set_locale", as: :locale

  get "up" => "rails/health#show", as: :rails_health_check

  root "projects#index"
end

