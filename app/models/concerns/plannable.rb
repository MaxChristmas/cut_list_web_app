module Plannable
  extend ActiveSupport::Concern

  PLANS = {
    "free" => {
      max_active_projects: 2,
      max_monthly_optimizations_per_project: 10
    },
    "worker" => {
      max_active_projects: 10,
      max_monthly_optimizations_per_project: Float::INFINITY
    },
    "enterprise" => {
      max_active_projects: Float::INFINITY,
      max_monthly_optimizations_per_project: Float::INFINITY
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

  def max_monthly_optimizations_per_project
    plan_config[:max_monthly_optimizations_per_project]
  end

  def active_projects_count
    projects.active.count
  end

  def can_create_project?
    active_projects_count < max_active_projects
  end

  def monthly_optimizations_count_for(project)
    project.optimizations
           .where(created_at: Time.current.beginning_of_month..)
           .count
  end

  def can_run_optimization?(project = nil)
    return true if project.nil? # new project, no optimizations yet
    monthly_optimizations_count_for(project) < max_monthly_optimizations_per_project
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
