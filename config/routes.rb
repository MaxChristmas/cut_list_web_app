Rails.application.routes.draw do
  resources :projects, param: :token do
    member do
      get :export_pdf
    end
  end

  devise_for :users, controllers: { registrations: "users/registrations", omniauth_callbacks: "users/omniauth_callbacks" }

  patch "locale", to: "application#set_locale", as: :locale

  get "up" => "rails/health#show", as: :rails_health_check

  root "projects#index"
end

