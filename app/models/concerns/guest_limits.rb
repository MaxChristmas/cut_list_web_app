module GuestLimits
  PLAN_CONFIG = Plannable::PLANS["free"]

  def self.has_feature?(feature)
    PLAN_CONFIG[:features].include?(feature.to_sym)
  end

  def self.monthly_count_for(project_token)
    project = Project.find_by(token: project_token)
    return 0 unless project

    count = project.optimizations
                   .where(created_at: Time.current.beginning_of_month..)
                   .count
    if project.created_at >= Time.current.beginning_of_month
      [count - 1, 0].max
    else
      count
    end
  end

  def self.guest_tokens(session)
    session[:guest_project_tokens] || []
  end
end
