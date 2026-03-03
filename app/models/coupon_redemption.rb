class CouponRedemption < ApplicationRecord
  belongs_to :coupon
  belongs_to :user

  validates :coupon_id, uniqueness: { scope: :user_id }
end
