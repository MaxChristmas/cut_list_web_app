require "rails_helper"

RSpec.describe CouponRedemption, type: :model do
  def create_user(overrides = {})
    User.create!({
      email: "redemption-user@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true
    }.merge(overrides))
  end

  def create_coupon(overrides = {})
    Coupon.create!({
      plan: "worker",
      duration_days: 30
    }.merge(overrides))
  end

  describe "associations" do
    it "belongs to a coupon" do
      assoc = described_class.reflect_on_association(:coupon)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to a user" do
      assoc = described_class.reflect_on_association(:user)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "prevents the same user from redeeming the same coupon twice" do
      user = create_user
      coupon = create_coupon

      CouponRedemption.create!(coupon: coupon, user: user)
      duplicate = CouponRedemption.new(coupon: coupon, user: user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:coupon_id]).to be_present
    end

    it "allows the same user to redeem different coupons" do
      user = create_user
      coupon1 = create_coupon
      coupon2 = create_coupon

      CouponRedemption.create!(coupon: coupon1, user: user)
      redemption2 = CouponRedemption.new(coupon: coupon2, user: user)
      expect(redemption2).to be_valid
    end

    it "allows different users to redeem the same coupon" do
      user1 = create_user(email: "user1@example.com")
      user2 = create_user(email: "user2@example.com")
      coupon = create_coupon

      CouponRedemption.create!(coupon: coupon, user: user1)
      redemption2 = CouponRedemption.new(coupon: coupon, user: user2)
      expect(redemption2).to be_valid
    end
  end
end
