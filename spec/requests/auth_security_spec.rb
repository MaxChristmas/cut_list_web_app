require "rails_helper"

RSpec.describe "Authentication security", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:password) { "password123" }

  let(:valid_signup_params) do
    {
      user: {
        email: "new-signup@example.com",
        password: password,
        terms_accepted: true
      }
    }
  end

  describe "registration rate limiting" do
    it "allows up to 5 registrations per hour" do
      5.times do |i|
        post user_registration_path, params: {
          user: {
            email: "ratelimit#{i}@example.com",
            password: password,
            terms_accepted: true
          }
        }
        expect(response).not_to redirect_to(new_user_registration_path),
          "Registration ##{i + 1} should be allowed"
        delete destroy_user_session_path
      end
    end

    it "rejects the 6th registration within one hour" do
      5.times do |i|
        post user_registration_path, params: {
          user: {
            email: "ratelimit#{i}@example.com",
            password: password,
            terms_accepted: true
          }
        }
        delete destroy_user_session_path
      end

      post user_registration_path, params: valid_signup_params
      expect(response).to redirect_to(new_user_registration_path)
    end
  end

  describe "sign-in rate limiting" do
    let!(:user) do
      User.create!(
        email: "ratelimit-login@example.com",
        password: password,
        password_confirmation: password,
        terms_accepted: true
      )
    end

    it "allows up to 10 sign-in attempts within 15 minutes" do
      10.times do |i|
        post user_session_path, params: { user: { email: "nobody#{i}@example.com", password: "wrong" } }
        expect(response).not_to redirect_to(new_user_session_path),
          "Sign-in attempt ##{i + 1} should not be rate-limited yet"
      end
    end

    it "rejects the 11th sign-in attempt within 15 minutes" do
      10.times do |i|
        post user_session_path, params: { user: { email: "nobody#{i}@example.com", password: "wrong" } }
      end

      post user_session_path, params: { user: { email: user.email, password: password } }
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "honeypot" do
    it "silently rejects registration when honeypot field is filled" do
      expect {
        post user_registration_path, params: valid_signup_params.merge(website: "http://spam.com")
      }.not_to change(User, :count)

      expect(response).to have_http_status(:ok)
    end

    it "allows registration when honeypot field is empty" do
      expect {
        post user_registration_path, params: valid_signup_params
      }.to change(User, :count).by(1)
    end

    it "allows registration when honeypot field is absent" do
      expect {
        post user_registration_path, params: valid_signup_params.merge(user: { email: "absent-honeypot@example.com", password: password, terms_accepted: true })
      }.to change(User, :count).by(1)
    end
  end

  describe "account lockable" do
    let!(:user) do
      User.create!(
        email: "lockable@example.com",
        password: password,
        password_confirmation: password,
        terms_accepted: true
      )
    end

    it "locks the account after 10 failed attempts" do
      10.times do
        post user_session_path, params: { user: { email: user.email, password: "wrongpassword" } }
      end

      user.reload
      expect(user.failed_attempts).to eq(10)
      expect(user.locked_at).to be_present
    end

    it "rejects sign-in with correct password when account is locked" do
      10.times do
        post user_session_path, params: { user: { email: user.email, password: "wrongpassword" } }
      end

      post user_session_path, params: { user: { email: user.email, password: password } }
      expect(response).not_to redirect_to(root_path)
    end

    it "auto-unlocks the account after 30 minutes" do
      10.times do
        post user_session_path, params: { user: { email: user.email, password: "wrongpassword" } }
      end

      expect(user.reload.locked_at).to be_present

      travel_to(31.minutes.from_now) do
        post user_session_path, params: { user: { email: user.email, password: password } }
        expect(response).to redirect_to(root_path)
      end
    end

    it "resets failed attempts after a successful sign-in" do
      3.times do
        post user_session_path, params: { user: { email: user.email, password: "wrongpassword" } }
      end

      expect(user.reload.failed_attempts).to eq(3)

      post user_session_path, params: { user: { email: user.email, password: password } }
      expect(user.reload.failed_attempts).to eq(0)
    end

    it "does not increment failed attempts for non-existent email" do
      post user_session_path, params: { user: { email: "nobody@example.com", password: "wrongpassword" } }

      expect(user.reload.failed_attempts).to eq(0)
    end
  end
end
