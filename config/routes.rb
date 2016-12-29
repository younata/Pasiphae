Rails.application.routes.draw do
  get 'status_board_controller/current'
  get 'status_board_controller/popular'
  get 'status_board_controller/usage'

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      put  'user/create', to: 'user#create'
      post 'user/login', to: 'user#login'
      put  'user/add_device_token', to: 'user#add_device_token'
      delete 'user/delete', to: 'user#delete'

      post 'feeds/subscribe', to: 'feeds#subscribe'
      post 'feeds/unsubscribe', to: 'feeds#unsubscribe'
      post 'feeds/fetch', to: 'feeds#fetch'
      get 'feeds/check', to: 'feeds#check'
      get 'feeds/feeds', to: 'feeds#feeds'
      get 'feeds/articles', to: 'feeds#articles'

      post 'articles/update', to: 'articles#update'
    end
  end

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
