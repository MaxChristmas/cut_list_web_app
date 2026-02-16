module Admin
  class SessionsController < Devise::SessionsController
    layout "admin_login"

    private

    def after_sign_in_path_for(_resource)
      admin_root_path
    end

    def after_sign_out_path_for(_resource)
      new_admin_user_session_path
    end
  end
end
