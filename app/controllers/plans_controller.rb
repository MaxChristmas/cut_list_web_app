class PlansController < ApplicationController
  before_action :authenticate_user!, only: %i[checkout portal]

  def index
    @plans = Plannable::PLANS
    @current_plan = user_signed_in? ? current_user.plan : "free"
    @billing_cycle = params[:billing_cycle] || "monthly"
  end

  def checkout
    plan = params[:plan]
    billing_cycle = params[:billing_cycle]&.to_sym || :monthly

    unless Plannable::PLANS.key?(plan)
      return redirect_to plans_path, alert: t("plans.invalid")
    end

    config = Plannable::PLANS[plan]

    # Free plan: downgrade directly (only via portal if currently subscribed)
    if config[:prices].nil?
      if current_user.stripe_subscription_id.present?
        return redirect_to plans_path, alert: t("plans.use_portal_to_downgrade")
      end
      current_user.update!(plan: plan)
      return redirect_to plans_path, notice: t("plans.updated", plan: t("plans.#{plan}.name"))
    end

    price_id = Plannable.stripe_price_id(plan, billing_cycle)
    unless price_id.present?
      return redirect_to plans_path, alert: t("plans.invalid")
    end

    customer_id = current_user.find_or_create_stripe_customer!

    session = Stripe::Checkout::Session.create(
      customer: customer_id,
      mode: "subscription",
      line_items: [{ price: price_id, quantity: 1 }],
      success_url: plan_success_url(plan: plan),
      cancel_url: plans_url,
      metadata: { user_id: current_user.id, plan: plan }
    )

    redirect_to session.url, allow_other_host: true
  end

  def success
    @plan = params[:plan]
    redirect_to plans_path, notice: t("plans.checkout_success")
  end

  def portal
    unless current_user.stripe_customer_id.present?
      return redirect_to plans_path, alert: t("plans.no_subscription")
    end

    session = Stripe::BillingPortal::Session.create(
      customer: current_user.stripe_customer_id,
      return_url: plans_url
    )

    redirect_to session.url, allow_other_host: true
  end
end
