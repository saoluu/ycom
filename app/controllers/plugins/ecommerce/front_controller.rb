class Plugins::Ecommerce::FrontController < CamaleonCms::Apps::PluginsFrontController

  prepend_before_action :init_flash
  before_action :ecommerce_add_assets_in_front
  before_action :save_cache_redirect, only: [:login, :register]
  def login
    puts cama_current_user
    @user ||= current_site.users.new
    render 'login'
  end

  def do_login

    if login_user_with_password(params[:email], params[:password])
      if !@user.is_valid_email? and current_site.need_validate_email?
        flash[:error] = t('camaleon_cms.admin.login.message.email_not_validated')
        return login
      end

      callback_login(@user)
      login_user(@user, false, (cookies[:e_return_to] || plugins_ecommerce_orders_path))
      return cookies.delete(:e_return_to)
    else
      flash[:cama_ecommerce][:error] = t('plugins.ecommerce.messages.invalid_access', default: 'Invalid access')
      return login
    end
  
  end


  def confirm_email
    @user = current_site.users.new
    if params[:h]
      @user = current_site.users.where(confirm_email_token: params[:h]).first
      if @user.nil?
        flash[:error] = t('camaleon_cms.admin.login.message.confirm_email_token_incorrect')
      elsif @user.confirm_email_sent_at.nil? || @user.confirm_email_sent_at < 2.hours.ago
        flash[:error] = t('camaleon_cms.admin.login.message.confirm_email_token_expired')
      else
        flash[:notice] = t('camaleon_cms.admin.login.message.confirm_email_success')
        @user.is_valid_email = true
        @user.save!
      end
    end
    redirect_to plugins_ecommerce_login_url 
  end


  def register
    params[:kind_form] = 'register-form'
    @user ||= current_site.users.new
    render 'login'
  end

  def do_register

    puts params[:kind_form] 

    params[:camaleon_cms_user][:username] = params[:camaleon_cms_user][:email] if params[:camaleon_cms_user].present?
    @user = current_site.users.new(params.require(:camaleon_cms_user).permit(:business_name,:tax_code,:first_name, :last_name, :username, :email, :password, :password_confirmation,:is_valid_email))
    @user[:is_valid_email] = false if current_site.need_validate_email?
    
    if @user.save
      send_user_confirm_email(@user,false, params[:kind_form]=='register-form-partners' ) if current_site.need_validate_email?
      flash[:cama_ecommerce][:notice] = t('plugins.ecommerce.messages.created_account', default: "Account created successfully")
      return login
      # callback_login(@user)
      # login_user(@user, false, (cookies[:e_return_to] || plugins_ecommerce_orders_path))
      return cookies.delete(:e_return_to)
    else
      return register
    end
  end

  require 'securerandom'

  def google_login
    user_info = request.env['omniauth.auth']["info"]

    @user = current_site.users.find_by_email user_info["email"]

    if !@user
      random_string = SecureRandom.hex
      @user = current_site.users.create({
        first_name: user_info["first_name"],
        last_name: user_info["last_name"],
        username: user_info["email"].split("@").first,
        email: user_info["email"],
        password: random_string,
        password_confirmation: random_string

      })
    end
    callback_login(@user)
    login_user(@user, false, plugins_ecommerce_orders_path)
    return cookies.delete(:e_return_to)
  end

  def facebook_login 
    user_info = request.env['omniauth.auth']["info"]

    auth = request.env['omniauth.auth']
    if auth.to_hash["info"]["email"].nil?
      email = request.env['omniauth.auth']["uid"] + "@facebook.com"
    else
      email = auth.to_hash["info"]["email"]
    end
    @user = current_site.users.find_by_email email

    if !@user
      random_string = SecureRandom.hex
      @user = current_site.users.create({
        first_name: user_info["name"],
        last_name: "",
        username: user_info["name"],
        email: email,
        password: random_string,
        password_confirmation: random_string

      })
    end
    callback_login(@user)
    login_user(@user, false, plugins_ecommerce_orders_path)
    return cookies.delete(:e_return_to)
  end


  private
  def save_cache_redirect
    cookies[:e_return_to] = params[:return_to] if params[:return_to].present?
  end

  def commerce_authenticate
    unless cama_sign_in?
      flash[:cama_ecommerce][:error] = t('camaleon_cms.admin.login.please_login')
      cookies[:e_return_to] = request.referer
      redirect_to plugins_ecommerce_login_path
    end
  end

  def init_flash
    flash[:cama_ecommerce] = {} unless flash[:cama_ecommerce].present?
  end


  # callback after log in
  def callback_login(user)
    if cookies[:e_cart_id].present?
      e_current_cart(ecommerce_get_visitor_key).change_user(user)
      cookies.delete(:e_cart_id)
    end
  end


end
