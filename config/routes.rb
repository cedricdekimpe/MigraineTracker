Rails.application.routes.draw do
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'

  # API routes (no locale scope)
  namespace :api do
    namespace :v1 do
      # Authentication
      post 'auth/register', to: 'auth#register'
      post 'auth/login', to: 'auth#login'
      delete 'auth/logout', to: 'auth#logout'
      post 'auth/refresh', to: 'auth#refresh'
      get 'auth/me', to: 'auth#me'

      # User profile
      get 'user/profile', to: 'users#show'
      patch 'user/profile', to: 'users#update'
      delete 'user', to: 'users#destroy'

      # Data management
      get 'data/export', to: 'data#export'
      post 'data/import', to: 'data#import'

      # Resources
      resources :migraines, only: %i[index show create update destroy] do
        collection do
          get :calendar
          get :yearly
        end
      end

      resources :medications, only: %i[index show create update destroy]

      # Statistics
      get 'stats', to: 'stats#index'
      get 'stats/monthly', to: 'stats#monthly'
      get 'stats/by_day_of_week', to: 'stats#by_day_of_week'
      get 'stats/by_medication', to: 'stats#by_medication'
      get 'stats/by_nature', to: 'stats#by_nature'
      get 'stats/by_intensity', to: 'stats#by_intensity'
    end
  end

  # Locale scope for internationalization
  scope "(:locale)", locale: /en|fr/ do
    devise_for :users, controllers: { registrations: 'users/registrations' }
    
    # Static pages
    get 'faq', to: 'pages#faq', as: :faq
    
    # Account settings pages
    get 'account', to: 'account#show', as: :account
    get 'account/profile', to: 'account#profile', as: :account_profile
    get 'account/medications', to: 'account#medications', as: :account_medications
    get 'account/data', to: 'account#data', as: :account_data
    
    # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

    # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
    # Can be used by load balancers and uptime monitors to verify that the app is live.
    get "up" => "rails/health#show", as: :rails_health_check

    # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
    # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
    # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

    resources :migraines, only: %i[index new create edit update destroy] do
      collection do
        get :yearly
        get :history
      end
    end

    resources :medications, only: %i[create destroy]

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
