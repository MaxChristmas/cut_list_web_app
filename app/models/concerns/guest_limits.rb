module GuestLimits
  PLAN_CONFIG = Plannable::PLANS["free"]

  def self.can_create_project?(session)
    guest_tokens(session).size < PLAN_CONFIG[:max_active_projects]
  end

  def self.can_run_optimization?(session)
    daily_count(session) < PLAN_CONFIG[:max_daily_optimizations]
  end

  def self.record_optimization!(session)
    session[:guest_optimizations] ||= []
    session[:guest_optimizations] << Time.current.to_i
  end

  def self.daily_count(session)
    cutoff = Time.current.beginning_of_day.to_i
    optimizations = session[:guest_optimizations] || []
    recent = optimizations.select { |t| t >= cutoff }
    session[:guest_optimizations] = recent
    recent.size
  end

  def self.guest_tokens(session)
    session[:guest_project_tokens] || []
  end

  def self.track_project!(session, token)
    session[:guest_project_tokens] ||= []
    session[:guest_project_tokens] << token unless session[:guest_project_tokens].include?(token)
  end
end
