class Api::V1::ApiController < ApplicationController
  protect_from_forgery with: :null_session
  skip_before_filter :verify_authenticity_token
  before_filter :restrict_access

  private
  def restrict_access
    if request.headers['X-APP-TOKEN'] != ENV['PASIPHAE_APPLICATION_TOKEN']
      request_http_token_authentication
    end
  end
end
