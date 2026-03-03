require "rails_helper"

RSpec.describe "Admin::Coupons", type: :request do
  let(:admin_password) { "adminpass123" }

  let(:admin_user) do
    AdminUser.create!(
      email: "admin@example.com",
      password: admin_password,
      password_confirmation: admin_password
    )
  end

  def sign_in_admin
    post admin_user_session_path, params: {
      admin_user: { email: admin_user.email, password: admin_password }
    }
  end

  def create_coupon(overrides = {})
    Coupon.create!({
      plan: "worker",
      duration_days: 30
    }.merge(overrides))
  end

  describe "without authentication" do
    it "redirects to admin sign in" do
      get admin_coupons_path
      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  describe "with authentication" do
    before { sign_in_admin }

    describe "GET /admin/coupons" do
      it "returns success" do
        get admin_coupons_path
        expect(response).to have_http_status(:ok)
      end

      it "lists existing coupons" do
        coupon = create_coupon(code: "LIST01")
        get admin_coupons_path
        expect(response.body).to include("LIST01")
      end
    end

    describe "GET /admin/coupons/:id" do
      it "shows coupon details" do
        coupon = create_coupon(code: "SHOW01")
        get admin_coupon_path(coupon)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("SHOW01")
      end

      it "shows redemption history" do
        coupon = create_coupon(code: "SHOW02")
        user = User.create!(
          email: "redeemer@example.com",
          password: "password123",
          password_confirmation: "password123",
          terms_accepted: true
        )
        coupon.redeem!(user)

        get admin_coupon_path(coupon)
        expect(response.body).to include("redeemer@example.com")
      end
    end

    describe "GET /admin/coupons/new" do
      it "returns success" do
        get new_admin_coupon_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "POST /admin/coupons" do
      it "creates a coupon with auto-generated code" do
        expect {
          post admin_coupons_path, params: {
            coupon: { plan: "worker", duration_days: 30 }
          }
        }.to change(Coupon, :count).by(1)

        coupon = Coupon.last
        expect(coupon.code).to match(/\A[0-9A-Z]{6}\z/)
        expect(coupon.plan).to eq("worker")
        expect(coupon.duration_days).to eq(30)
        expect(response).to redirect_to(admin_coupon_path(coupon))
      end

      it "creates a coupon with a custom code" do
        post admin_coupons_path, params: {
          coupon: { code: "CUSTOM", plan: "enterprise", duration_days: 90 }
        }

        coupon = Coupon.last
        expect(coupon.code).to eq("CUSTOM")
        expect(coupon.plan).to eq("enterprise")
      end

      it "creates a coupon with max_uses" do
        post admin_coupons_path, params: {
          coupon: { plan: "worker", duration_days: 30, max_uses: 10 }
        }

        expect(Coupon.last.max_uses).to eq(10)
      end

      it "creates a coupon with expires_at" do
        expires = 1.week.from_now.change(sec: 0)
        post admin_coupons_path, params: {
          coupon: { plan: "worker", duration_days: 30, expires_at: expires.iso8601 }
        }

        expect(Coupon.last.expires_at).to be_within(1.minute).of(expires)
      end

      it "re-renders form on invalid params" do
        post admin_coupons_path, params: {
          coupon: { plan: "invalid", duration_days: 30 }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(Coupon.count).to eq(0)
      end
    end

    describe "GET /admin/coupons/:id/edit" do
      it "returns success" do
        coupon = create_coupon
        get edit_admin_coupon_path(coupon)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "PATCH /admin/coupons/:id" do
      it "updates coupon attributes" do
        coupon = create_coupon(plan: "worker", duration_days: 30)
        patch admin_coupon_path(coupon), params: {
          coupon: { plan: "enterprise", duration_days: 90 }
        }

        expect(response).to redirect_to(admin_coupon_path(coupon))
        coupon.reload
        expect(coupon.plan).to eq("enterprise")
        expect(coupon.duration_days).to eq(90)
      end

      it "allows code change when unused" do
        coupon = create_coupon(code: "OLD001")
        patch admin_coupon_path(coupon), params: {
          coupon: { code: "NEW001" }
        }

        expect(response).to redirect_to(admin_coupon_path(coupon))
        expect(coupon.reload.code).to eq("NEW001")
      end

      it "rejects code change when used" do
        coupon = create_coupon(code: "USED01")
        coupon.update_column(:uses_count, 1)

        patch admin_coupon_path(coupon), params: {
          coupon: { code: "CHANGE" }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(coupon.reload.code).to eq("USED01")
      end

      it "re-renders form on invalid params" do
        coupon = create_coupon
        patch admin_coupon_path(coupon), params: {
          coupon: { plan: "invalid" }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "DELETE /admin/coupons/:id" do
      it "deletes the coupon" do
        coupon = create_coupon

        expect {
          delete admin_coupon_path(coupon)
        }.to change(Coupon, :count).by(-1)

        expect(response).to redirect_to(admin_coupons_path)
      end

      it "deletes associated redemptions" do
        coupon = create_coupon
        user = User.create!(
          email: "delete-test@example.com",
          password: "password123",
          password_confirmation: "password123",
          terms_accepted: true
        )
        coupon.redeem!(user)

        expect {
          delete admin_coupon_path(coupon)
        }.to change(CouponRedemption, :count).by(-1)
      end
    end
  end
end
