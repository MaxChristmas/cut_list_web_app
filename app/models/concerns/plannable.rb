module Plannable
  extend ActiveSupport::Concern

  PLANS = {
    "free" => {
      max_active_projects: 2,
      max_daily_optimizations: 5
    },
    "worker" => {
      max_active_projects: 10,
      max_daily_optimizations: 100
    },
    "enterprise" => {
      max_active_projects: Float::INFINITY,
      max_daily_optimizations: Float::INFINITY
    }
  }.freeze

  included do
    validates :plan, inclusion: { in: PLANS.keys }
  end

  def plan_config
    PLANS[plan]
  end

  def max_active_projects
    plan_config[:max_active_projects]
  end

  def max_daily_optimizations
    plan_config[:max_daily_optimizations]
  end

  def active_projects_count
    projects.active.count
  end

  def can_create_project?
    active_projects_count < max_active_projects
  end

  def daily_optimizations_count
    projects.joins(:optimizations)
            .where(optimizations: { created_at: Time.current.beginning_of_day.. })
            .count
  end

  def can_run_optimization?
    daily_optimizations_count < max_daily_optimizations
  end

  def free_plan?
    plan == "free"
  end

  def worker_plan?
    plan == "worker"
  end

  def enterprise_plan?
    plan == "enterprise"
  end
end
