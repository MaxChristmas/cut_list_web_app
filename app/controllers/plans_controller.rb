class PlansController < ApplicationController
  before_action :authenticate_user!, only: %i[checkout portal]

  def index
    @plans = Plannable::PLANS
    @current_plan = user_signed_in? ? current_user.effective_plan : "free"
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

    price_config = config[:prices][billing_cycle]
    unless price_config.present? && ENV[price_config[:env_key]].present?
      return redirect_to plans_path, alert: t("plans.invalid")
    end

    customer_id = current_user.find_or_create_stripe_customer!

    is_one_shot = billing_cycle == :one_shot

    description_key = is_one_shot ? "one_shot" : "subscription"
    checkout_description = I18n.t("plans.checkout_description.#{description_key}")
    plan_name = is_one_shot ? t("plans.one_shot.name") : t("plans.pro.name")

    line_item = {
      quantity: 1,
      price_data: {
        currency: "eur",
        unit_amount: price_config[:amount],
        product_data: {
          name: "CutOptima #{plan_name}",
          description: checkout_description
        }
      }
    }

    unless is_one_shot
      interval = billing_cycle == :yearly ? "year" : "month"
      line_item[:price_data][:recurring] = { interval: interval }
    end

    session = Stripe::Checkout::Session.create(
      customer: customer_id,
      mode: is_one_shot ? "payment" : "subscription",
      locale: I18n.locale.to_s,
      line_items: [ line_item ],
      billing_address_collection: "required",
      tax_id_collection: { enabled: true },
      customer_update: { name: "auto", address: "auto" },
      success_url: "#{plan_success_url(plan: plan)}&session_id={CHECKOUT_SESSION_ID}",
      cancel_url: plans_url,
      metadata: { user_id: current_user.id, plan: plan, one_shot: is_one_shot.to_s }
    )

    redirect_to session.url, allow_other_host: true
  end

  def success
    if params[:session_id].present? && user_signed_in?
      begin
        session = Stripe::Checkout::Session.retrieve(params[:session_id])
        if session.payment_status == "paid" && session.metadata["user_id"] == current_user.id.to_s
          plan = session.metadata["plan"]
          if Plannable::PLANS.key?(plan)
            if session.metadata["one_shot"] == "true"
              current_user.update!(plan: plan, plan_expires_at: 3.days.from_now, stripe_subscription_id: nil)
            else
              current_user.update!(plan: plan, plan_expires_at: nil, stripe_subscription_id: session.subscription)
            end
          end
        end
      rescue Stripe::StripeError => e
        Rails.logger.error("Stripe session retrieval failed: #{e.message}")
      end
    end

    redirect_to root_path, notice: t("plans.checkout_success")
  end

  def portal
    unless current_user.stripe_customer_id.present?
      return redirect_to plans_path, alert: t("plans.no_subscription")
    end

    session = Stripe::BillingPortal::Session.create(
      customer: current_user.stripe_customer_id,
      return_url: plans_url,
      locale: I18n.locale.to_s
    )

    redirect_to session.url, allow_other_host: true
  end
end
