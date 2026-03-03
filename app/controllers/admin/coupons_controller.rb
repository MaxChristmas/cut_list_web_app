module Admin
  class CouponsController < BaseController
    before_action :set_coupon, only: [ :show, :edit, :update, :destroy ]

    def index
      @coupons = paginate(Coupon.order(created_at: :desc))
    end

    def show
      @redemptions = @coupon.coupon_redemptions.includes(:user).order(created_at: :desc)
    end

    def new
      @coupon = Coupon.new
    end

    def create
      @coupon = Coupon.new(coupon_params)
      if @coupon.save
        redirect_to admin_coupon_path(@coupon), notice: "Coupon created: #{@coupon.code}"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @coupon.update(coupon_params)
        redirect_to admin_coupon_path(@coupon), notice: "Coupon updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @coupon.destroy
      redirect_to admin_coupons_path, notice: "Coupon deleted."
    end

    private

    def set_coupon
      @coupon = Coupon.find(params[:id])
    end

    def coupon_params
      params.expect(coupon: [ :code, :plan, :duration_days, :expires_at, :max_uses ])
    end
  end
end
