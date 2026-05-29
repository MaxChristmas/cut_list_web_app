require "rails_helper"

RSpec.describe "Marketing consent settings", type: :request do
  let(:user) do
    User.create!(
      email: "consent-settings-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true
    )
  end

  def sign_in_user
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end

  describe "PATCH /notifications" do
    context "when signed in" do
      before { sign_in_user }

      it "sets marketing_consent_at when consent is given" do
        patch user_notifications_path, params: { marketing_consent: "1" }
        expect(user.reload.marketing_consent_at).to be_present
      end

      it "clears marketing_consent_at when consent is revoked" do
        user.update!(marketing_consent_at: 1.day.ago)
        patch user_notifications_path, params: { marketing_consent: "0" }
        expect(user.reload.marketing_consent_at).to be_nil
      end

      it "clears marketing_consent_at when checkbox is unchecked (param absent)" do
        user.update!(marketing_consent_at: 1.day.ago)
        patch user_notifications_path
        expect(user.reload.marketing_consent_at).to be_nil
      end

      it "redirects to settings page" do
        patch user_notifications_path, params: { marketing_consent: "1" }
        expect(response).to redirect_to(edit_user_registration_path)
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        patch user_notifications_path, params: { marketing_consent: "1" }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
