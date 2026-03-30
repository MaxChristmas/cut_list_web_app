Rails.application.routes.draw do
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker"
  devise_for :admin_users, path: "admin", controllers: {
    sessions: "admin/sessions"
  }

  namespace :admin do
    root "dashboard#index"
    resources :users do
      patch :soft_delete, on: :member
    end
    resources :projects, only: [ :index, :show ] do
      resources :optimizations, only: [ :index, :show ]
    end
    resources :report_issues, except: [ :new, :create ] do
      post :reply, on: :member
    end
    resources :coupons
    resources :feedbacks, only: [ :index, :show, :destroy ]
    resources :scan_tokens, only: [ :index, :show ]
  end

  resources :projects, param: :token do
    member do
      get :export_pdf
      get :export_dxf
      get :export_labels
      patch :archive
      patch :unarchive
      patch :save_layout
      patch :reset_layout
    end
  end

  resources :plans, only: [ :index ]
  post "plans/checkout", to: "plans#checkout", as: :plan_checkout
  get "plans/success", to: "plans#success", as: :plan_success
  post "plans/portal", to: "plans#portal", as: :plan_portal

  post "stripe/webhooks", to: "stripe_webhooks#create"

  devise_for :users, controllers: { registrations: "users/registrations", omniauth_callbacks: "users/omniauth_callbacks", sessions: "users/sessions", passwords: "users/passwords" }

  resources :scan_tokens, only: [ :create ] do
    patch :submit_pieces, on: :member
  end

  scope :scan do
    get ":token", to: "scans#show", as: :scan
    post ":token/upload", to: "scans#upload", as: :scan_upload
  end

  resources :coupons, only: [ :create ]
  resources :feedbacks, only: [ :create, :update ] do
    post :dismiss, on: :collection
  end
  resources :report_issues, only: [ :create ]

  patch "locale", to: "application#set_locale", as: :locale

  get "faq", to: "pages#faq", as: :faq
  get "cookies-policy", to: "pages#cookies_policy", as: :cookies_policy
  get "legal-notices", to: "pages#legal_notices", as: :legal_notices
  get "privacy-policy", to: "pages#privacy_policy", as: :privacy_policy

  get "up" => "rails/health#show", as: :rails_health_check

  root "projects#index"
end
