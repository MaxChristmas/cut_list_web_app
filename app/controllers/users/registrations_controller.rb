class Users::RegistrationsController < Devise::RegistrationsController
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 5, within: 1.hour, only: [ :create ],
             store: RATE_LIMIT_STORE,
             with: -> { redirect_to new_user_registration_path, alert: I18n.t("devise.registrations.rate_limited") }

  def create
    if params[:website].present?
      head :ok
      return
    end

    super do |user|
      claim_guest_projects(user) if user.persisted?
    end
  end

  protected

  def sign_up_params
    params.require(:user).permit(:email, :password, :terms_accepted)
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
