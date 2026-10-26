Rails.application.routes.draw do
  # Installable app: the service worker sits at the root so that it covers both languages
  get "service-worker" => "pwa#service_worker", as: :pwa_service_worker, defaults: { format: :js }

  # Sitemap (no locale scope, but accessible from any locale)
  get "sitemap.xml", to: "sitemap#index", format: :xml, as: :sitemap

  # Locale scope for internationalization
  scope "(:locale)", locale: /en|fr/ do
    devise_for :users, controllers: { registrations: "users/registrations" }

    # Static pages
    get "faq", to: "pages#faq", as: :faq
    get "privacy-policy", to: "pages#privacy", as: :privacy
    get "urgent", to: "pages#urgent", as: :urgent
    get "why-free", to: "pages#free", as: :why_free
    get "about-ai", to: "pages#about_ai", as: :about_ai
    get "numbers", to: "pages#numbers", as: :numbers

    # Account settings pages
    get "account", to: "account#show", as: :account
    get "account/profile", to: "account#profile", as: :account_profile
    get "account/medications", to: "account#medications", as: :account_medications
    get "account/triggers", to: "account#triggers", as: :account_triggers
    get "account/data", to: "account#data", as: :account_data
    patch "account/preferences", to: "account#update_preferences", as: :account_preferences
    patch "account/onboarding", to: "account#dismiss_onboarding", as: :account_onboarding
    patch "account/notifications", to: "account#update_notifications", as: :account_notifications
    # This device accepts notifications (web push)
    post "account/push_subscriptions", to: "push_subscriptions#create", as: :push_subscriptions

    # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

    # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
    # Can be used by load balancers and uptime monitors to verify that the app is live.
    get "up" => "rails/health#show", as: :rails_health_check

    # Installable app: manifest and offline page in the visitor's language
    get "manifest" => "pwa#manifest", as: :pwa_manifest, defaults: { format: :json }
    get "offline" => "pwa#offline", as: :offline

    # "I have a headache now"
    get "now", to: "now#show", as: :now
    post "now", to: "now#create"
    delete "now", to: "now#cancel"
    patch "now/intensity", to: "now#intensity", as: :now_intensity
    post "now/medication", to: "now#medication", as: :now_medication
    delete "now/intakes/:id", to: "now#remove_intake", as: :now_intake
    patch "now/finish", to: "now#finish", as: :now_finish
    post "now/offline", to: "now#offline", as: :now_offline
    get "now/effects/:episode_id", to: "now#effects", as: :now_effects
    patch "now/intakes/:id/effect", to: "now#effect", as: :now_intake_effect
    patch "now/nausea/:episode_id", to: "now#nausea", as: :now_nausea

    # The daily check-in (sleep, stress, meals, caffeine)
    get "check", to: "daily_checks#today", as: :check
    resources :daily_checks, path: "check", param: :date, only: %i[show update], constraints: { date: /\d{4}-\d{2}-\d{2}/ }

    # Bleeding days of the cycle row, one tap each
    resources :period_days, only: %i[create destroy], param: :date, constraints: { date: /\d{4}-\d{2}-\d{2}/ }

    # Same thing before having an account; kept in the session until sign-in
    resource :guest_episode, only: %i[show create destroy], path: "noted"

    resources :episodes, only: %i[index new create edit update destroy] do
      collection do
        get :yearly
        get :history
      end
    end

    resources :medications, only: %i[create update destroy] do
      patch :unarchive, on: :member
      resources :treatment_periods, only: %i[create update destroy]
    end

    resources :triggers, only: %i[create destroy]

    resources :stats, only: [ :index ]

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
