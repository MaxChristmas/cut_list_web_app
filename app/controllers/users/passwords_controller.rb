class Users::PasswordsController < Devise::PasswordsController
  rate_limit to: 5, within: 1.hour, only: :create

  def create
    User.send_reset_password_instructions(resource_params)

    # Always return success to prevent email enumeration
    if request.format.json? || request.xhr?
      render json: { success: true }, status: :ok
    else
      redirect_to root_path, notice: I18n.t("devise.passwords.send_instructions")
    end
  end

  # Redirect to root with token — the modal will auto-open
  def edit
    redirect_to root_path(reset_password_token: params[:reset_password_token])
  end
end
