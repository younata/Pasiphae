class Api::V1::ApiController < ApplicationController
  protect_from_forgery with: :null_session
  before_filter :restrict_access

  private
  def restrict_access
    if request.headers['APP_TOKEN'] != ENV['PASIPHAE_APPLICATION_TOKEN']
      request_http_token_authentication
    end
  end
end
