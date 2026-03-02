class Users::SessionsController < Devise::SessionsController
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 10, within: 15.minutes, only: [ :create ],
             store: RATE_LIMIT_STORE,
             with: -> { redirect_to new_user_session_path, alert: I18n.t("devise.sessions.rate_limited") }

  def create
    super do |user|
      claim_guest_projects(user)
    end
  end

  def destroy
    locale = session[:locale]
    super
    session[:locale] = locale
  end
end
