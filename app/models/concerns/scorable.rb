module Scorable
  extend ActiveSupport::Concern

  # Engagement score (0–100) based on plan, connections, projects, and optimizations.
  #
  # Breakdown:
  #   Plan:          0–30 pts (free=0, coupon=30%, paid=100% of worker/enterprise value)
  #   Sign-ins:      0–25 pts (logarithmic, caps at ~50 sign-ins)
  #   Projects:      0–20 pts (logarithmic, caps at ~10 projects)
  #   Optimizations: 0–25 pts (logarithmic, caps at ~50 optimizations)

  SCORE_WEIGHTS = {
    plan: 30,
    sign_ins: 25,
    projects: 20,
    optimizations: 25
  }.freeze

  PLAN_SCORES = {
    "free" => 0,
    "worker" => 0.5,
    "enterprise" => 1.0
  }.freeze

  def engagement_score
    scores = engagement_score_breakdown
    scores.values.sum.round
  end

  def engagement_score_breakdown
    {
      plan: plan_score,
      sign_ins: sign_ins_score,
      projects: projects_score,
      optimizations: optimizations_score
    }
  end

  private

  COUPON_DISCOUNT = 0.3

  def plan_score
    # Use the subscribed plan (not effective_plan) so users who paid
    # are still valued even after their plan expires.
    multiplier = PLAN_SCORES[plan] || 0
    # Coupon-only users get a reduced plan score.
    # A user who paid via Stripe AND used a coupon keeps the full score.
    multiplier *= COUPON_DISCOUNT if plan != "free" && coupon_only?
    (SCORE_WEIGHTS[:plan] * multiplier).round(1)
  end

  def coupon_only?
    coupon_redemptions.any? && stripe_subscription_id.blank?
  end

  def sign_ins_score
    log_score(sign_in_count, cap: 50, weight: SCORE_WEIGHTS[:sign_ins])
  end

  def projects_score
    log_score(projects.size, cap: 10, weight: SCORE_WEIGHTS[:projects])
  end

  def optimizations_score
    count = projects.sum(:optimizations_count)
    log_score(count, cap: 50, weight: SCORE_WEIGHTS[:optimizations])
  end

  # Logarithmic scaling: score = weight * log(1 + value) / log(1 + cap)
  # Returns 0 when value=0, approaches weight when value >= cap
  def log_score(value, cap:, weight:)
    return 0.0 if value <= 0
    raw = Math.log(1 + value) / Math.log(1 + cap)
    ([ raw, 1.0 ].min * weight).round(1)
  end
end
