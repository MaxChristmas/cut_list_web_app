module Plannable
  extend ActiveSupport::Concern

  FEATURES = %i[
    pdf_export label_pieces cut_direction blade_kerf
    import_csv print_labels margin archive move_pieces
  ].freeze

  PLANS = {
    "free" => {
      max_active_projects: 2,
      max_daily_optimizations_per_project: 10,
      features: %i[pdf_export label_pieces cut_direction],
      prices: nil
    },
    "worker" => {
      max_active_projects: 10,
      max_daily_optimizations_per_project: Float::INFINITY,
      features: %i[pdf_export label_pieces cut_direction blade_kerf import_csv print_labels],
      prices: {
        monthly:  { amount: 1000, env_key: "STRIPE_WORKER_MONTHLY_PRICE_ID" },
        yearly:   { amount: 10000, env_key: "STRIPE_WORKER_YEARLY_PRICE_ID" },
        one_shot: { amount: 500, env_key: "STRIPE_WORKER_ONE_SHOT_PRICE_ID" }
      }
    },
    "enterprise" => {
      max_active_projects: Float::INFINITY,
      max_daily_optimizations_per_project: Float::INFINITY,
      features: FEATURES,
      prices: {
        monthly:  { amount: 2000, env_key: "STRIPE_ENTERPRISE_MONTHLY_PRICE_ID" },
        yearly:   { amount: 20000, env_key: "STRIPE_ENTERPRISE_YEARLY_PRICE_ID" },
        one_shot: { amount: 800, env_key: "STRIPE_ENTERPRISE_ONE_SHOT_PRICE_ID" }
      }
    }
  }.freeze

  def self.stripe_price_id(plan, billing_cycle)
    config = PLANS.dig(plan, :prices, billing_cycle)
    return nil unless config

    ENV[config[:env_key]]
  end

  included do
    validates :plan, inclusion: { in: PLANS.keys }
  end

  def plan_config
    return PLANS["free"] if plan_expired?
    PLANS[plan]
  end

  def effective_plan
    plan_expired? ? "free" : plan
  end

  def plan_expired?
    plan_expires_at.present? && plan_expires_at < Time.current
  end

  def one_shot_plan?
    plan_expires_at.present? && !plan_expired?
  end

  def max_active_projects
    plan_config[:max_active_projects]
  end

  def max_daily_optimizations_per_project
    plan_config[:max_daily_optimizations_per_project]
  end

  def active_projects_count
    projects.active.count
  end

  def can_create_project?
    active_projects_count < max_active_projects
  end

  def daily_optimizations_count_for(project)
    count = project.optimizations
                   .where(created_at: Time.current.beginning_of_day..)
                   .count
    # Don't count the initial creation optimization
    if project.created_at >= Time.current.beginning_of_day
      [count - 1, 0].max
    else
      count
    end
  end

  def can_run_optimization?(project = nil)
    return true if project.nil? # new project, no optimizations yet
    daily_optimizations_count_for(project) < max_daily_optimizations_per_project
  end

  def has_feature?(feature)
    plan_config[:features].include?(feature.to_sym)
  end

  def free_plan?
    effective_plan == "free"
  end

  def worker_plan?
    effective_plan == "worker"
  end

  def enterprise_plan?
    effective_plan == "enterprise"
  end

  def paid_plan?
    worker_plan? || enterprise_plan?
  end

  def find_or_create_stripe_customer!
    return stripe_customer_id if stripe_customer_id.present?

    customer = Stripe::Customer.create(email: email, metadata: { user_id: id })
    update!(stripe_customer_id: customer.id)
    customer.id
  end
end
