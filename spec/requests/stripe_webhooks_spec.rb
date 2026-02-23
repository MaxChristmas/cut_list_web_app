require "rails_helper"

RSpec.describe "Stripe webhooks – subscription lifecycle", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let!(:user) do
    User.create!(
      email: "stripe-test@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true,
      plan: "worker",
      stripe_customer_id: "cus_test123",
      stripe_subscription_id: "sub_test123"
    )
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("STRIPE_WORKER_MONTHLY_PRICE_ID").and_return("price_worker_monthly")
    allow(ENV).to receive(:[]).with("STRIPE_WORKER_YEARLY_PRICE_ID").and_return("price_worker_yearly")
  end

  def post_webhook(event_hash)
    stripe_event = Stripe::Event.construct_from(event_hash)
    allow(Stripe::Webhook).to receive(:construct_event).and_return(stripe_event)

    post stripe_webhooks_path,
         params: event_hash.to_json,
         headers: { "Content-Type" => "application/json", "HTTP_STRIPE_SIGNATURE" => "t=0,v1=fake" }
  end

  def subscription_updated_event(cancel_at_period_end:, current_period_end:)
    {
      id: "evt_#{SecureRandom.hex(8)}",
      type: "customer.subscription.updated",
      data: {
        object: {
          id: "sub_test123",
          customer: "cus_test123",
          cancel_at_period_end: cancel_at_period_end,
          current_period_end: current_period_end.to_i,
          items: { data: [{ price: { id: "price_worker_monthly" } }] }
        }
      }
    }
  end

  describe "subscription cancellation" do
    it "keeps the plan active until the end of the billing period" do
      period_end = 25.days.from_now

      post_webhook subscription_updated_event(
        cancel_at_period_end: true,
        current_period_end: period_end
      )

      user.reload
      expect(user.plan).to eq("worker")
      expect(user.plan_expires_at).to be_within(1.second).of(period_end)
      expect(user.plan_expired?).to be false
    end

    it "falls back to free plan limits after the billing period ends" do
      period_end = 2.days.from_now

      post_webhook subscription_updated_event(
        cancel_at_period_end: true,
        current_period_end: period_end
      )

      user.reload
      expect(user.plan_expired?).to be false
      expect(user.max_active_projects).to eq(10)

      travel_to period_end + 1.hour do
        expect(user.plan_expired?).to be true
        expect(user.effective_plan).to eq("free")
        expect(user.max_active_projects).to eq(2)
        expect(user.max_monthly_optimizations_per_project).to eq(10)
      end
    end

    it "clears expiration when a cancelled subscription is reactivated" do
      user.update!(plan_expires_at: 10.days.from_now)

      post_webhook subscription_updated_event(
        cancel_at_period_end: false,
        current_period_end: 30.days.from_now
      )

      user.reload
      expect(user.plan).to eq("worker")
      expect(user.plan_expires_at).to be_nil
    end
  end

  describe "subscription deleted" do
    it "downgrades to free plan immediately" do
      post_webhook({
        id: "evt_#{SecureRandom.hex(8)}",
        type: "customer.subscription.deleted",
        data: { object: { id: "sub_test123", customer: "cus_test123" } }
      })

      user.reload
      expect(user.plan).to eq("free")
      expect(user.stripe_subscription_id).to be_nil
      expect(user.plan_expires_at).to be_nil
    end
  end

  describe "one-shot purchase" do
    it "grants the plan for exactly 3 days then expires to free" do
      user.update!(plan: "free", stripe_subscription_id: nil)

      post_webhook({
        id: "evt_#{SecureRandom.hex(8)}",
        type: "checkout.session.completed",
        data: {
          object: {
            payment_status: "paid",
            subscription: nil,
            metadata: { user_id: user.id.to_s, plan: "worker", one_shot: "true" }
          }
        }
      })

      user.reload
      expect(user.plan).to eq("worker")
      expect(user.stripe_subscription_id).to be_nil
      expect(user.plan_expires_at).to be_within(5.seconds).of(3.days.from_now)

      # Still active right before expiry
      travel_to user.plan_expires_at - 1.hour do
        expect(user.plan_expired?).to be false
        expect(user.effective_plan).to eq("worker")
      end

      # Expired after the 3 days
      travel_to user.plan_expires_at + 1.hour do
        expect(user.plan_expired?).to be true
        expect(user.effective_plan).to eq("free")
        expect(user.max_active_projects).to eq(2)
      end
    end

    it "has no subscription to cancel" do
      user.update!(plan: "worker", stripe_subscription_id: nil, plan_expires_at: 2.days.from_now)

      expect(user.stripe_subscription_id).to be_nil
      expect(user.one_shot_plan?).to be true
    end
  end
end
