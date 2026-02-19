class Users::SessionsController < Devise::SessionsController
  def create
    super do |user|
      claim_guest_projects(user)
    end
  end

  def destroy
    tokens = current_user&.projects&.active&.pluck(:token) || []
    locale = session[:locale]
    super
    session[:guest_project_tokens] = tokens
    session[:locale] = locale
  end
end
