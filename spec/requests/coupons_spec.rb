require "rails_helper"

RSpec.describe "Coupon redemption", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:password) { "password123" }

  let(:user) do
    User.create!(
      email: "coupon-tester@example.com",
      password: password,
      password_confirmation: password,
      terms_accepted: true
    )
  end

  let(:coupon) do
    Coupon.create!(
      code: "TEST01",
      plan: "worker",
      duration_days: 30
    )
  end

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: password } }
  end

  describe "POST /coupons" do
    context "when not authenticated" do
      it "redirects to sign in" do
        post coupons_path, params: { code: coupon.code }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated" do
      before { sign_in(user) }

      it "redeems a valid coupon and upgrades the user" do
        post coupons_path, params: { code: coupon.code }

        expect(response).to redirect_to(edit_user_registration_path(tab: 3))
        expect(flash[:notice]).to be_present

        user.reload
        expect(user.plan).to eq("worker")
        expect(user.plan_expires_at).to be_present
      end

      it "sets plan_expires_at correctly" do
        freeze_time do
          post coupons_path, params: { code: coupon.code }

          user.reload
          expect(user.plan_expires_at).to be_within(1.second).of(30.days.from_now)
        end
      end

      it "creates a coupon redemption record" do
        expect {
          post coupons_path, params: { code: coupon.code }
        }.to change(CouponRedemption, :count).by(1)
      end

      it "increments the coupon uses_count" do
        post coupons_path, params: { code: coupon.code }
        expect(coupon.reload.uses_count).to eq(1)
      end

      it "normalizes the code to uppercase" do
        coupon # ensure coupon is created
        post coupons_path, params: { code: "test01" }
        expect(user.reload.plan).to eq("worker")
      end

      it "strips whitespace from the code" do
        coupon # ensure coupon is created
        post coupons_path, params: { code: "  TEST01  " }
        expect(user.reload.plan).to eq("worker")
      end

      context "with an invalid code" do
        it "redirects with alert" do
          post coupons_path, params: { code: "XXXXXX" }

          expect(response).to redirect_to(edit_user_registration_path(tab: 3))
          expect(flash[:alert]).to be_present
          expect(user.reload.plan).to eq("free")
        end
      end

      context "with an empty code" do
        it "redirects with alert" do
          post coupons_path, params: { code: "" }

          expect(response).to redirect_to(edit_user_registration_path(tab: 3))
          expect(flash[:alert]).to be_present
        end
      end

      context "with an expired coupon" do
        let(:expired_coupon) do
          Coupon.create!(
            code: "EXPIR1",
            plan: "worker",
            duration_days: 30,
            expires_at: 1.hour.ago
          )
        end

        it "rejects the coupon" do
          post coupons_path, params: { code: expired_coupon.code }

          expect(response).to redirect_to(edit_user_registration_path(tab: 3))
          expect(flash[:alert]).to be_present
          expect(user.reload.plan).to eq("free")
        end
      end

      context "with a maxed-out coupon" do
        let(:maxed_coupon) do
          c = Coupon.create!(
            code: "MAXED1",
            plan: "worker",
            duration_days: 30,
            max_uses: 1
          )
          c.update_column(:uses_count, 1)
          c
        end

        it "rejects the coupon" do
          post coupons_path, params: { code: maxed_coupon.code }

          expect(response).to redirect_to(edit_user_registration_path(tab: 3))
          expect(flash[:alert]).to be_present
          expect(user.reload.plan).to eq("free")
        end
      end

      context "when user already used the coupon" do
        before do
          coupon.redeem!(user)
        end

        it "rejects the second attempt" do
          post coupons_path, params: { code: coupon.code }

          expect(response).to redirect_to(edit_user_registration_path(tab: 3))
          expect(flash[:alert]).to be_present
        end
      end

      context "with an enterprise coupon" do
        let(:enterprise_coupon) do
          Coupon.create!(
            code: "ENTER1",
            plan: "enterprise",
            duration_days: 90
          )
        end

        it "upgrades to enterprise plan" do
          post coupons_path, params: { code: enterprise_coupon.code }

          user.reload
          expect(user.plan).to eq("enterprise")
        end
      end
    end
  end

  describe "rate limiting" do
    before { sign_in(user) }

    it "allows up to 5 attempts per hour" do
      5.times do
        post coupons_path, params: { code: "XXXXXX" }
        expect(response).to redirect_to(edit_user_registration_path(tab: 3))
        expect(flash[:alert]).not_to eq(I18n.t("coupons.rate_limited"))
      end
    end

    it "rejects the 6th attempt within one hour" do
      5.times { post coupons_path, params: { code: "XXXXXX" } }

      post coupons_path, params: { code: coupon.code }
      expect(response).to redirect_to(edit_user_registration_path(tab: 3))
      expect(flash[:alert]).to eq(I18n.t("coupons.rate_limited"))
      expect(user.reload.plan).to eq("free")
    end
  end
end
