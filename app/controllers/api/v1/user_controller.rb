class Api::V1::UserController < ApplicationController
  def create
    email = params[:email]
    password = params[:password]

    user = User.create(email: email, password: password, password_confirmation: password)
    device = user.devices.first
    render :json => {api_token: device.api_token}
  end

  def login
    render :json => true
  end

  def delete
    render :json => true
  end

  def add_device_token
    render :json => true
  end
end
