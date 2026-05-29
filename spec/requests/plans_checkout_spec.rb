require "rails_helper"

RSpec.describe "Plans checkout success", type: :request do
  let(:user) do
    User.create!(
      email: "checkout-test-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true,
      plan: "free"
    )
  end

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end

  describe "GET /plans/success" do
    let(:stripe_session) do
      double(
        payment_status: "paid",
        metadata: { "user_id" => user.id.to_s, "plan" => "worker", "one_shot" => "false" },
        subscription: "sub_test123"
      )
    end

    context "when payment is confirmed and user is signed in" do
      before do
        sign_in user
        allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(stripe_session)
      end

      it "upgrades the user plan" do
        get plan_success_path(plan: "worker", session_id: "cs_test123")
        expect(user.reload.plan).to eq("worker")
      end

      it "sets the stripe subscription id" do
        get plan_success_path(plan: "worker", session_id: "cs_test123")
        expect(user.reload.stripe_subscription_id).to eq("sub_test123")
      end

      it "redirects to root with post_checkout param so the pending form can be auto-submitted" do
        get plan_success_path(plan: "worker", session_id: "cs_test123")
        expect(response).to redirect_to(root_path(post_checkout: "1"))
      end

      it "sets a success notice" do
        get plan_success_path(plan: "worker", session_id: "cs_test123")
        follow_redirect!
        expect(flash[:notice]).to be_present
      end
    end

    context "when payment is not confirmed (unpaid)" do
      let(:unpaid_session) do
        double(
          payment_status: "unpaid",
          metadata: { "user_id" => user.id.to_s, "plan" => "worker", "one_shot" => "false" }
        )
      end

      before do
        sign_in user
        allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(unpaid_session)
      end

      it "does not upgrade the user plan" do
        get plan_success_path(plan: "worker", session_id: "cs_test123")
        expect(user.reload.plan).to eq("free")
      end

      it "still redirects to root with post_checkout param" do
        get plan_success_path(plan: "worker", session_id: "cs_test123")
        expect(response).to redirect_to(root_path(post_checkout: "1"))
      end
    end

    context "when session_id is missing (direct access)" do
      before { sign_in user }

      it "does not update the plan" do
        get plan_success_path(plan: "worker")
        expect(user.reload.plan).to eq("free")
      end

      it "still redirects to root with post_checkout param" do
        get plan_success_path(plan: "worker")
        expect(response).to redirect_to(root_path(post_checkout: "1"))
      end
    end

    context "when Stripe raises an error" do
      before do
        sign_in user
        allow(Stripe::Checkout::Session).to receive(:retrieve).and_raise(Stripe::StripeError.new("Network error"))
      end

      it "does not update the plan" do
        get plan_success_path(plan: "worker", session_id: "cs_test123")
        expect(user.reload.plan).to eq("free")
      end

      it "still redirects to root gracefully with post_checkout param" do
        get plan_success_path(plan: "worker", session_id: "cs_test123")
        expect(response).to redirect_to(root_path(post_checkout: "1"))
      end
    end

    context "when user is not signed in" do
      before do
        allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(stripe_session)
      end

      it "still redirects to root with post_checkout param" do
        get plan_success_path(plan: "worker", session_id: "cs_test123")
        expect(response).to redirect_to(root_path(post_checkout: "1"))
      end

      it "does not update the user plan" do
        get plan_success_path(plan: "worker", session_id: "cs_test123")
        expect(user.reload.plan).to eq("free")
      end
    end

    context "one-shot payment" do
      let(:one_shot_session) do
        double(
          payment_status: "paid",
          metadata: { "user_id" => user.id.to_s, "plan" => "worker", "one_shot" => "true" },
          subscription: nil
        )
      end

      before do
        sign_in user
        allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(one_shot_session)
      end

      it "upgrades the plan with an expiry date" do
        get plan_success_path(plan: "worker", session_id: "cs_test123")
        user.reload
        expect(user.plan).to eq("worker")
        expect(user.plan_expires_at).to be_present
        expect(user.plan_expires_at).to be_within(5.seconds).of(3.days.from_now)
      end

      it "does not set a subscription id" do
        get plan_success_path(plan: "worker", session_id: "cs_test123")
        expect(user.reload.stripe_subscription_id).to be_nil
      end

      it "redirects to root with post_checkout param" do
        get plan_success_path(plan: "worker", session_id: "cs_test123")
        expect(response).to redirect_to(root_path(post_checkout: "1"))
      end
    end
  end
end
