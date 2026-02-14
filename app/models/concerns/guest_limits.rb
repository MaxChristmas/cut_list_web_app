module GuestLimits
  PLAN_CONFIG = Plannable::PLANS["free"]

  def self.has_feature?(feature)
    PLAN_CONFIG[:features].include?(feature.to_sym)
  end

  def self.can_create_project?(session)
    guest_tokens(session).size < PLAN_CONFIG[:max_active_projects]
  end

  def self.can_run_optimization?(session, project_token = nil)
    return true if project_token.nil? # new project, no optimizations yet
    monthly_count_for(session, project_token) < PLAN_CONFIG[:max_monthly_optimizations_per_project]
  end

  def self.record_optimization!(session, project_token)
    session[:guest_optimizations] ||= []
    session[:guest_optimizations] << { token: project_token, at: Time.current.to_i }
  end

  def self.monthly_count_for(session, project_token)
    cutoff = Time.current.beginning_of_month.to_i
    optimizations = session[:guest_optimizations] || []
    recent = optimizations.select { |o| o["at"] >= cutoff || o[:at].to_i >= cutoff }
    session[:guest_optimizations] = recent
    recent.count { |o| (o["token"] || o[:token]) == project_token }
  end

  def self.guest_tokens(session)
    session[:guest_project_tokens] || []
  end

  def self.track_project!(session, token)
    session[:guest_project_tokens] ||= []
    session[:guest_project_tokens] << token unless session[:guest_project_tokens].include?(token)
  end
end
