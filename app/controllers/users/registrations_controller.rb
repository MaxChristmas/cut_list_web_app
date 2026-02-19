class Users::RegistrationsController < Devise::RegistrationsController
  def create
    super do |user|
      claim_guest_projects(user) if user.persisted?
    end
  end

  protected

  def sign_up_params
    params.require(:user).permit(:email, :password)
  end

  def after_update_path_for(resource)
    edit_user_registration_path
  end

  def update_resource(resource, params)
    if params[:password].blank?
      params.delete(:password)
      params.delete(:password_confirmation)
      resource.update_without_password(params)
    else
      resource.update_with_password(params)
    end
  end
end
