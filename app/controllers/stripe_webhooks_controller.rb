class StripeWebhooksController < ApplicationController
  skip_forgery_protection

  def create
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, ENV["STRIPE_WEBHOOK_SECRET"])
    rescue JSON::ParserError, Stripe::SignatureVerificationError
      head :bad_request
      return
    end

    case event.type
    when "checkout.session.completed"
      handle_checkout_completed(event.data.object)
    when "customer.subscription.updated"
      handle_subscription_updated(event.data.object)
    when "customer.subscription.deleted"
      handle_subscription_deleted(event.data.object)
    end

    head :ok
  end

  private

  def handle_checkout_completed(session)
    user = User.find_by(id: session.metadata["user_id"])
    return unless user

    plan = session.metadata["plan"]
    return unless Plannable::PLANS.key?(plan)

    if session.metadata["one_shot"] == "true"
      user.update!(
        plan: plan,
        plan_expires_at: 3.days.from_now,
        stripe_subscription_id: nil
      )
    else
      user.update!(
        plan: plan,
        plan_expires_at: nil,
        stripe_subscription_id: session.subscription
      )
    end
  end

  def handle_subscription_updated(subscription)
    user = User.find_by(stripe_customer_id: subscription.customer)
    return unless user

    # Map Stripe price ID back to plan name
    price_id = subscription.items.data.first&.price&.id
    plan = plan_for_price_id(price_id)

    user.update!(plan: plan, stripe_subscription_id: subscription.id) if plan
  end

  def handle_subscription_deleted(subscription)
    user = User.find_by(stripe_customer_id: subscription.customer)
    return unless user

    user.update!(plan: "free", stripe_subscription_id: nil, plan_expires_at: nil)
  end

  def plan_for_price_id(price_id)
    Plannable::PLANS.each do |plan_name, config|
      next unless config[:prices]
      config[:prices].each_key do |cycle|
        return plan_name if Plannable.stripe_price_id(plan_name, cycle) == price_id
      end
    end
    nil
  end
end
