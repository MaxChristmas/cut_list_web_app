require "rails_helper"

RSpec.describe "Password reset", type: :request do
  let(:password) { "password123" }
  let(:new_password) { "newpassword456" }

  let!(:user) do
    User.create!(
      email: "reset@example.com",
      password: password,
      password_confirmation: password,
      terms_accepted: true
    )
  end

  describe "POST /users/password (request reset)" do
    it "returns 200 for an existing email" do
      post user_password_path, params: { user: { email: user.email } },
            headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a non-existing email (no enumeration)" do
      post user_password_path, params: { user: { email: "unknown@example.com" } },
            headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
    end

    it "sends a reset email for an existing user" do
      expect {
        post user_password_path, params: { user: { email: user.email } },
              headers: { "Accept" => "application/json" }
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "does not send a reset email for a non-existing user" do
      expect {
        post user_password_path, params: { user: { email: "unknown@example.com" } },
              headers: { "Accept" => "application/json" }
      }.not_to change { ActionMailer::Base.deliveries.count }
    end
  end

  describe "GET /users/password/edit (follow email link)" do
    it "redirects to root with the reset token" do
      token = user.send_reset_password_instructions

      get edit_user_password_path(reset_password_token: token)

      expect(response).to redirect_to(root_path(reset_password_token: token))
    end
  end

  describe "PUT /users/password (update password)" do
    it "updates the password with a valid token" do
      raw_token = user.send_reset_password_instructions

      put user_password_path, params: {
        user: {
          reset_password_token: raw_token,
          password: new_password,
          password_confirmation: new_password
        }
      }

      expect(response).to redirect_to(root_path)
      expect(user.reload.valid_password?(new_password)).to be true
    end

    it "rejects update with an invalid token" do
      put user_password_path, params: {
        user: {
          reset_password_token: "invalid-token",
          password: new_password,
          password_confirmation: new_password
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.valid_password?(password)).to be true
    end

    it "rejects update when passwords do not match" do
      raw_token = user.send_reset_password_instructions

      put user_password_path, params: {
        user: {
          reset_password_token: raw_token,
          password: new_password,
          password_confirmation: "mismatch"
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.valid_password?(password)).to be true
    end

    it "rejects update when password is too short" do
      raw_token = user.send_reset_password_instructions

      put user_password_path, params: {
        user: {
          reset_password_token: raw_token,
          password: "short",
          password_confirmation: "short"
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.valid_password?(password)).to be true
    end

    it "signs in the user after successful password reset" do
      raw_token = user.send_reset_password_instructions

      put user_password_path, params: {
        user: {
          reset_password_token: raw_token,
          password: new_password,
          password_confirmation: new_password
        }
      }

      follow_redirect!
      expect(response).to have_http_status(:ok)
    end
  end
end
