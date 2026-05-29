class Users::NotificationsController < ApplicationController
  before_action :authenticate_user!

  def update
    if params[:marketing_consent] == "1"
      current_user.update!(marketing_consent_at: Time.current)
    else
      current_user.update!(marketing_consent_at: nil)
    end

    redirect_to edit_user_registration_path, notice: t("settings.notifications.saved")
  end
end
