require "rails_helper"

RSpec.describe Coupon, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  def build_coupon(overrides = {})
    Coupon.new({
      plan: "worker",
      duration_days: 30
    }.merge(overrides))
  end

  def create_coupon(overrides = {})
    build_coupon(overrides).tap(&:save!)
  end

  def create_user(overrides = {})
    User.create!({
      email: "coupon-user@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true
    }.merge(overrides))
  end

  describe "validations" do
    it "is valid with valid attributes" do
      expect(build_coupon).to be_valid
    end

    it "requires a plan" do
      expect(build_coupon(plan: nil)).not_to be_valid
    end

    it "requires plan to be worker or enterprise" do
      expect(build_coupon(plan: "free")).not_to be_valid
      expect(build_coupon(plan: "worker")).to be_valid
      expect(build_coupon(plan: "enterprise")).to be_valid
    end

    it "requires duration_days" do
      expect(build_coupon(duration_days: nil)).not_to be_valid
    end

    it "requires duration_days to be greater than 0" do
      expect(build_coupon(duration_days: 0)).not_to be_valid
      expect(build_coupon(duration_days: -1)).not_to be_valid
    end

    it "requires max_uses to be greater than 0 if present" do
      expect(build_coupon(max_uses: 0)).not_to be_valid
      expect(build_coupon(max_uses: -1)).not_to be_valid
      expect(build_coupon(max_uses: 1)).to be_valid
    end

    it "allows max_uses to be nil" do
      expect(build_coupon(max_uses: nil)).to be_valid
    end

    it "requires code to be 6 uppercase alphanumeric characters" do
      expect(build_coupon(code: "ABC12")).not_to be_valid
      expect(build_coupon(code: "ABC1234")).not_to be_valid
      expect(build_coupon(code: "ABCDEF")).to be_valid
      expect(build_coupon(code: "123456")).to be_valid
      expect(build_coupon(code: "A1B2C3")).to be_valid
    end

    it "accepts lowercase codes (normalized to uppercase)" do
      coupon = build_coupon(code: "abc123")
      expect(coupon).to be_valid
      coupon.save!
      expect(coupon.code).to eq("ABC123")
    end

    it "requires code to be unique" do
      create_coupon(code: "ABC123")
      expect(build_coupon(code: "ABC123")).not_to be_valid
    end
  end

  describe "code generation" do
    it "auto-generates a code on create if none provided" do
      coupon = build_coupon(code: nil)
      coupon.save!
      expect(coupon.code).to match(/\A[0-9A-Z]{6}\z/)
    end

    it "uses the provided code if given" do
      coupon = build_coupon(code: "CUTRUN")
      coupon.save!
      expect(coupon.code).to eq("CUTRUN")
    end

    it "normalizes code to uppercase" do
      coupon = build_coupon(code: "abcdef")
      coupon.save!
      expect(coupon.code).to eq("ABCDEF")
    end
  end

  describe "code immutability after use" do
    it "allows code change when uses_count is 0" do
      coupon = create_coupon(code: "AAAAAA")
      coupon.code = "BBBBBB"
      expect(coupon).to be_valid
    end

    it "prevents code change when uses_count > 0" do
      coupon = create_coupon(code: "AAAAAA")
      coupon.update_column(:uses_count, 1)
      coupon.code = "BBBBBB"
      expect(coupon).not_to be_valid
      expect(coupon.errors[:code]).to include("cannot be changed after the coupon has been used")
    end
  end

  describe "#redeemable?" do
    it "returns true for a fresh coupon" do
      expect(create_coupon).to be_redeemable
    end

    it "returns false when expired" do
      coupon = create_coupon(expires_at: 1.hour.ago)
      expect(coupon).not_to be_redeemable
    end

    it "returns true when not yet expired" do
      coupon = create_coupon(expires_at: 1.hour.from_now)
      expect(coupon).to be_redeemable
    end

    it "returns false when max_uses reached" do
      coupon = create_coupon(max_uses: 1)
      coupon.update_column(:uses_count, 1)
      expect(coupon).not_to be_redeemable
    end

    it "returns true when uses_count < max_uses" do
      coupon = create_coupon(max_uses: 5)
      coupon.update_column(:uses_count, 4)
      expect(coupon).to be_redeemable
    end

    it "returns true when max_uses is nil (unlimited)" do
      coupon = create_coupon(max_uses: nil)
      coupon.update_column(:uses_count, 100)
      expect(coupon).to be_redeemable
    end
  end

  describe "#expired?" do
    it "returns false when expires_at is nil" do
      expect(create_coupon(expires_at: nil)).not_to be_expired
    end

    it "returns false when expires_at is in the future" do
      expect(create_coupon(expires_at: 1.hour.from_now)).not_to be_expired
    end

    it "returns true when expires_at is in the past" do
      expect(create_coupon(expires_at: 1.hour.ago)).to be_expired
    end
  end

  describe ".active scope" do
    it "includes non-expired coupons with available uses" do
      active = create_coupon(expires_at: 1.day.from_now, max_uses: 10)
      expect(Coupon.active).to include(active)
    end

    it "excludes expired coupons" do
      expired = create_coupon(expires_at: 1.hour.ago)
      expect(Coupon.active).not_to include(expired)
    end

    it "excludes coupons that reached max_uses" do
      maxed = create_coupon(max_uses: 1)
      maxed.update_column(:uses_count, 1)
      expect(Coupon.active).not_to include(maxed)
    end

    it "includes coupons with no expiration" do
      no_expiry = create_coupon(expires_at: nil)
      expect(Coupon.active).to include(no_expiry)
    end

    it "includes coupons with no max_uses" do
      unlimited = create_coupon(max_uses: nil)
      unlimited.update_column(:uses_count, 999)
      expect(Coupon.active).to include(unlimited)
    end
  end

  describe "#redeem!" do
    let(:coupon) { create_coupon(plan: "worker", duration_days: 30) }
    let(:user) { create_user }

    it "creates a coupon redemption" do
      expect { coupon.redeem!(user) }.to change(CouponRedemption, :count).by(1)
    end

    it "increments uses_count" do
      expect { coupon.redeem!(user) }.to change { coupon.reload.uses_count }.from(0).to(1)
    end

    it "upgrades the user plan" do
      coupon.redeem!(user)
      user.reload
      expect(user.plan).to eq("worker")
    end

    it "sets plan_expires_at on the user" do
      freeze_time do
        coupon.redeem!(user)
        user.reload
        expect(user.plan_expires_at).to be_within(1.second).of(30.days.from_now)
      end
    end

    it "raises an error if the same user redeems twice" do
      coupon.redeem!(user)
      expect { coupon.redeem!(user) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
