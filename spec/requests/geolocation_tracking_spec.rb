require "rails_helper"

RSpec.describe "Geolocation tracking on authentication", type: :request do
  let(:password) { "password123" }
  let(:geo_result) do
    double("GeocoderResult", country: "France", city: "Paris")
  end

  before do
    allow(Geocoder).to receive(:search).and_return([ geo_result ])
  end

  describe "sign in via email/password" do
    let!(:user) do
      User.create!(
        email: "geo-test@example.com",
        password: password,
        password_confirmation: password,
        terms_accepted: true
      )
    end

    it "stores the IP immediately and enqueues geolocation job" do
      expect {
        post user_session_path, params: { user: { email: user.email, password: password } }
      }.to have_enqueued_job(GeocodeSignInJob).with(user, "127.0.0.1")

      user.reload
      expect(user.last_sign_in_ip).to eq("127.0.0.1")
    end

    it "stores geolocation when job is performed" do
      perform_enqueued_jobs do
        post user_session_path, params: { user: { email: user.email, password: password } }
      end

      user.reload
      expect(user.last_sign_in_ip).to eq("127.0.0.1")
      expect(user.last_sign_in_country).to eq("France")
      expect(user.last_sign_in_city).to eq("Paris")
    end

    it "does not break when Geocoder returns no results" do
      allow(Geocoder).to receive(:search).and_return([])

      perform_enqueued_jobs do
        post user_session_path, params: { user: { email: user.email, password: password } }
      end

      expect(response).to redirect_to(root_path)
      user.reload
      expect(user.last_sign_in_ip).to eq("127.0.0.1")
      expect(user.last_sign_in_country).to be_nil
      expect(user.last_sign_in_city).to be_nil
    end

    it "does not break when Geocoder raises an error" do
      allow(Geocoder).to receive(:search).and_raise(Geocoder::Error.new("timeout"))

      perform_enqueued_jobs do
        post user_session_path, params: { user: { email: user.email, password: password } }
      end

      expect(response).to redirect_to(root_path)
      user.reload
      expect(user.last_sign_in_ip).to eq("127.0.0.1")
    end

    it "skips geocoding when IP has not changed" do
      user.update_columns(last_sign_in_ip: "127.0.0.1", last_sign_in_country: "France", last_sign_in_city: "Paris")

      expect {
        post user_session_path, params: { user: { email: user.email, password: password } }
      }.not_to have_enqueued_job(GeocodeSignInJob)
    end
  end

  describe "sign up" do
    it "stores IP and enqueues geolocation on registration" do
      perform_enqueued_jobs do
        post user_registration_path, params: {
          user: {
            email: "new-user@example.com",
            password: password,
            password_confirmation: password,
            terms_accepted: true
          }
        }
      end

      user = User.find_by(email: "new-user@example.com")
      expect(user).to be_present
      expect(user.last_sign_in_ip).to eq("127.0.0.1")
      expect(user.last_sign_in_country).to eq("France")
      expect(user.last_sign_in_city).to eq("Paris")
    end

    it "does not break registration when Geocoder fails" do
      allow(Geocoder).to receive(:search).and_raise(Geocoder::Error.new("timeout"))

      perform_enqueued_jobs do
        post user_registration_path, params: {
          user: {
            email: "new-user2@example.com",
            password: password,
            password_confirmation: password,
            terms_accepted: true
          }
        }
      end

      expect(User.find_by(email: "new-user2@example.com")).to be_present
    end
  end
end
