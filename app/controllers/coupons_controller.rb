class CouponsController < ApplicationController
  before_action :authenticate_user!

  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 5, within: 1.hour, only: [ :create ],
             store: RATE_LIMIT_STORE,
             with: -> { redirect_to edit_user_registration_path(tab: 3), alert: I18n.t("coupons.rate_limited") }

  def create
    coupon = Coupon.find_by(code: params[:code].to_s.strip.upcase)

    if coupon.nil? || !coupon.redeemable?
      redirect_to edit_user_registration_path(tab: 3), alert: I18n.t("coupons.invalid")
      return
    end

    if coupon.coupon_redemptions.exists?(user: current_user)
      redirect_to edit_user_registration_path(tab: 3), alert: I18n.t("coupons.already_used")
      return
    end

    coupon.redeem!(current_user)
    redirect_to edit_user_registration_path(tab: 3), notice: I18n.t("coupons.success", plan: coupon.plan.capitalize, days: coupon.duration_days)
  end
end
