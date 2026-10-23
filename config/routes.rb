Rails.application.routes.draw do
  # Sitemap (no locale scope, but accessible from any locale)
  get 'sitemap.xml', to: 'sitemap#index', format: :xml, as: :sitemap

  # Locale scope for internationalization
  scope "(:locale)", locale: /en|fr/ do
    devise_for :users, controllers: { registrations: 'users/registrations' }
    
    # Static pages
    get 'faq', to: 'pages#faq', as: :faq
    get 'privacy-policy', to: 'pages#privacy', as: :privacy
    
    # Account settings pages
    get 'account', to: 'account#show', as: :account
    get 'account/profile', to: 'account#profile', as: :account_profile
    get 'account/medications', to: 'account#medications', as: :account_medications
    get 'account/triggers', to: 'account#triggers', as: :account_triggers
    get 'account/data', to: 'account#data', as: :account_data
    patch 'account/preferences', to: 'account#update_preferences', as: :account_preferences
    
    # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

    # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
    # Can be used by load balancers and uptime monitors to verify that the app is live.
    get "up" => "rails/health#show", as: :rails_health_check

    # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
    # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
    # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

    resources :episodes, only: %i[index new create edit update destroy] do
      collection do
        get :yearly
        get :history
      end
    end

    resources :medications, only: %i[create update destroy] do
      patch :unarchive, on: :member
    end

    resources :triggers, only: %i[create destroy]

    resources :stats, only: [:index]

    # Data export/import
    post "exports", to: "exports#create", as: :exports
    get "imports/new", to: "imports#new", as: :new_import
    post "imports", to: "imports#create", as: :imports

    # Defines the root path route ("/")
    root "home#index"
  end
  
  # Redirect root to default locale
  root to: redirect("/#{I18n.default_locale}", status: 302), as: :redirected_root
end
