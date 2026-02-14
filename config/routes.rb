Rails.application.routes.draw do
  resources :projects, param: :token do
    member do
      get :export_pdf
      get :export_labels
      patch :archive
      patch :unarchive
    end
  end

  resources :plans, only: [:index]
  patch "plans/select", to: "plans#update", as: :select_plan

  devise_for :users, controllers: { registrations: "users/registrations", omniauth_callbacks: "users/omniauth_callbacks", sessions: "users/sessions" }

  resources :report_issues, only: [:create]

  patch "locale", to: "application#set_locale", as: :locale

  get "up" => "rails/health#show", as: :rails_health_check

  root "projects#index"
end
