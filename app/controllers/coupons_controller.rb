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

    location = [ current_user.last_sign_in_city, current_user.last_sign_in_country ].compact.join(", ")
    location = "Unknown" if location.blank?
    message = [
      "Email: #{current_user.email}",
      "Coupon: #{coupon.code} (#{coupon.duration_days} days)",
      "Plan: #{coupon.plan.capitalize}",
      "Time: #{Time.current.strftime('%b %d, %Y at %H:%M UTC')}",
      "Location: #{location}"
    ].join("\n")

    NtfyJob.perform_later("Coupon redeemed: #{coupon.plan.capitalize}", message, "ticket") rescue nil

    redirect_to edit_user_registration_path(tab: 3), notice: I18n.t("coupons.success", plan: coupon.plan.capitalize, days: coupon.duration_days)
  end
end
