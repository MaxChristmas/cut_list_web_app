require "rails_helper"

RSpec.describe Scorable, type: :model do
  def create_user(overrides = {})
    User.create!({
      email: "score-test-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123"
    }.merge(overrides))
  end

  def create_coupon
    Coupon.create!(plan: "worker", duration_days: 30)
  end

  def redeem_coupon(user)
    coupon = create_coupon
    coupon.redeem!(user)
  end

  def create_project_with_optimizations(user, optimization_count: 1)
    project = user.projects.create!(name: "Project", sheet_width: 100, sheet_length: 100)
    optimization_count.times do
      project.optimizations.create!(result: {}, efficiency: 0.8, sheets_count: 1, status: "completed")
    end
    project
  end

  describe "#engagement_score" do
    it "returns 0 for a brand new free user with no activity" do
      user = create_user
      expect(user.engagement_score).to eq(0)
    end

    it "returns a low score for a free user with minimal activity" do
      user = create_user(sign_in_count: 1)
      create_project_with_optimizations(user, optimization_count: 1)

      score = user.engagement_score
      expect(score).to be_between(1, 15)
    end

    it "returns a high score for an enterprise user with heavy usage" do
      user = create_user(plan: "enterprise", stripe_subscription_id: "sub_123", sign_in_count: 50)
      5.times { create_project_with_optimizations(user, optimization_count: 10) }

      score = user.engagement_score
      expect(score).to be >= 80
    end

    it "gives a significant boost for paid plans" do
      free_user = create_user(sign_in_count: 10)
      paid_user = create_user(plan: "worker", stripe_subscription_id: "sub_123", sign_in_count: 10)

      expect(paid_user.engagement_score - free_user.engagement_score).to eq(15)
    end

    it "caps at 100" do
      user = create_user(plan: "enterprise", stripe_subscription_id: "sub_123", sign_in_count: 1000)
      20.times { create_project_with_optimizations(user, optimization_count: 100) }

      expect(user.engagement_score).to eq(100)
    end
  end

  describe "#engagement_score_breakdown" do
    it "returns a hash with all score components" do
      user = create_user
      breakdown = user.engagement_score_breakdown

      expect(breakdown).to have_key(:plan)
      expect(breakdown).to have_key(:sign_ins)
      expect(breakdown).to have_key(:projects)
      expect(breakdown).to have_key(:optimizations)
    end

    it "scores paid plan correctly (with Stripe subscription)" do
      free_user = create_user(plan: "free")
      worker_user = create_user(plan: "worker", stripe_subscription_id: "sub_123")
      enterprise_user = create_user(plan: "enterprise", stripe_subscription_id: "sub_456")

      expect(free_user.engagement_score_breakdown[:plan]).to eq(0)
      expect(worker_user.engagement_score_breakdown[:plan]).to eq(15.0)
      expect(enterprise_user.engagement_score_breakdown[:plan]).to eq(30.0)
    end

    it "reduces plan score for coupon-only users" do
      coupon_worker = create_user
      redeem_coupon(coupon_worker)
      coupon_worker.reload

      paid_worker = create_user(plan: "worker", stripe_subscription_id: "sub_123")

      coupon_score = coupon_worker.engagement_score_breakdown[:plan]
      paid_score = paid_worker.engagement_score_breakdown[:plan]

      expect(coupon_score).to be < paid_score
      expect(coupon_score).to eq(4.5) # 30 * 0.5 * 0.3
      expect(paid_score).to eq(15.0)  # 30 * 0.5
    end

    it "gives full plan score to a Stripe subscriber who also used a coupon" do
      user = create_user(plan: "worker", stripe_subscription_id: "sub_123")
      redeem_coupon(user)
      user.reload

      expect(user.engagement_score_breakdown[:plan]).to eq(15.0)
    end

    it "still scores expired paid plan based on subscribed plan" do
      user = create_user(plan: "worker", stripe_subscription_id: "sub_123", plan_expires_at: 1.day.ago)
      expect(user.engagement_score_breakdown[:plan]).to eq(15.0)
    end

    it "increases sign_ins score logarithmically" do
      user1 = create_user(sign_in_count: 1)
      user5 = create_user(sign_in_count: 5)
      user50 = create_user(sign_in_count: 50)

      s1 = user1.engagement_score_breakdown[:sign_ins]
      s5 = user5.engagement_score_breakdown[:sign_ins]
      s50 = user50.engagement_score_breakdown[:sign_ins]

      expect(s1).to be > 0
      expect(s5).to be > s1
      expect(s50).to be >= s5
      expect(s50).to be <= 25
    end
  end
end
