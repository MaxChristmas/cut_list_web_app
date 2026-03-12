module GuestLimits
  PLAN_CONFIG = Plannable::PLANS["free"]

  def self.has_feature?(feature)
    PLAN_CONFIG[:features].include?(feature.to_sym)
  end

  def self.guest_tokens(session)
    session[:guest_project_tokens] || []
  end
end
