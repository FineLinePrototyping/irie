Rails.application.routes.draw do
  resources :barfoos

  namespace :example do
    namespace :alpha do
      scope '/awesome_routing_scope' do
        resources :foobars
      end
      resources :special_barfoos
    end
    namespace :beta do
      resources :foobars
    end
  end
end
