class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  around_action :switch_locale
  before_action :load_recent_projects

  helper_method :can_create_project?, :can_run_optimization?, :current_plan_name,
                :usage_projects, :usage_optimizations

  def set_locale
    locale = params[:locale].to_s.strip.to_sym
    if I18n.available_locales.include?(locale)
      session[:locale] = locale
    end
    redirect_back fallback_location: root_path
  end

  private

  def switch_locale(&action)
    locale = session[:locale] || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def load_recent_projects
    if user_signed_in?
      @recent_projects = current_user.projects.active.order(created_at: :desc).limit(20)
    else
      tokens = session[:guest_project_tokens] || []
      @recent_projects = Project.where(token: tokens).active.order(created_at: :desc).limit(20)
    end
  end

  def can_create_project?
    if user_signed_in?
      current_user.can_create_project?
    else
      GuestLimits.can_create_project?(session)
    end
  end

  def can_run_optimization?
    if user_signed_in?
      current_user.can_run_optimization?
    else
      GuestLimits.can_run_optimization?(session)
    end
  end

  def current_plan_name
    if user_signed_in?
      current_user.plan
    else
      "free"
    end
  end

  def usage_projects
    config = Plannable::PLANS[current_plan_name]
    if user_signed_in?
      { used: current_user.active_projects_count, max: config[:max_active_projects] }
    else
      { used: GuestLimits.guest_tokens(session).size, max: config[:max_active_projects] }
    end
  end

  def usage_optimizations
    config = Plannable::PLANS[current_plan_name]
    if user_signed_in?
      { used: current_user.daily_optimizations_count, max: config[:max_daily_optimizations] }
    else
      { used: GuestLimits.daily_count(session), max: config[:max_daily_optimizations] }
    end
  end
end
