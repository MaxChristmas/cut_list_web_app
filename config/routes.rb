Rails.application.routes.draw do
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker"
  devise_for :admin_users, path: "admin", controllers: {
    sessions: "admin/sessions"
  }

  namespace :admin do
    root "dashboard#index"
    resources :users
    resources :projects, only: [ :index, :show ] do
      resources :optimizations, only: [ :index, :show ]
    end
    resources :report_issues, except: [ :new, :create ] do
      post :reply, on: :member
    end
  end

  resources :projects, param: :token do
    member do
      get :export_pdf
      get :export_labels
      patch :archive
      patch :unarchive
      patch :save_layout
      patch :reset_layout
    end
  end

  resources :plans, only: [:index]
  post "plans/checkout", to: "plans#checkout", as: :plan_checkout
  get "plans/success", to: "plans#success", as: :plan_success
  post "plans/portal", to: "plans#portal", as: :plan_portal

  post "stripe/webhooks", to: "stripe_webhooks#create"

  devise_for :users, controllers: { registrations: "users/registrations", omniauth_callbacks: "users/omniauth_callbacks", sessions: "users/sessions" }

  resources :report_issues, only: [:create]

  patch "locale", to: "application#set_locale", as: :locale

  get "cookies-policy", to: "pages#cookies_policy", as: :cookies_policy
  get "legal-notices", to: "pages#legal_notices", as: :legal_notices

  get "up" => "rails/health#show", as: :rails_health_check

  root "projects#index"
end
