class Api::V1::UserController < Api::V1::ApiController
  before_filter :restrict_api_access, only: [:delete, :add_device_token]

  def create
    email = params[:email].downcase
    password = params[:password]

    if User.exists?(email: email)
      render :json => {error: 'User Exists'}, :status => :bad_request
    else
      user = User.create(email: email, password: password, password_confirmation: password)
      user.save
      device = user.devices.first
      render :json => {api_token: device.api_token}
    end
  end

  def login
    email = params[:email].downcase
    password = params[:password]

    user = User.find_by(email: email)
    if user.try(:authenticate, password)
      device = Device.create(user: user)
      device.save
      render :json => {api_token: device.api_token}
    else
      render :json => {error: 'Invalid email or password'}, :status => :not_found
    end
  end

  def delete
    @user.destroy
    render nothing: true
  end

  def add_device_token
    push_token = params[:token]
    @device.push_token = push_token
    @device.save
    render :json => true
  end

private

  def restrict_api_access
    authenticate_or_request_with_http_token do |token, options|
      if Device.exists?(api_token: token)
        @device = Device.find_by(api_token: token)
        @user = @device.user
        true
      else
        false
      end
    end
  end
end
