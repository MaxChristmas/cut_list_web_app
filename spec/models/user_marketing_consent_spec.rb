require "rails_helper"

RSpec.describe User, type: :model do
  def create_user(overrides = {})
    User.create!({
      email: "consent-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true
    }.merge(overrides))
  end

  describe "#marketing_consented?" do
    it "returns false when marketing_consent_at is nil" do
      user = create_user
      expect(user.marketing_consented?).to be false
    end

    it "returns true when marketing_consent_at is set" do
      user = create_user
      user.update!(marketing_consent_at: Time.current)
      expect(user.marketing_consented?).to be true
    end
  end

  describe "marketing_consent virtual attribute on create" do
    it "sets marketing_consent_at when marketing_consent is true" do
      user = create_user(marketing_consent: true)
      expect(user.marketing_consent_at).to be_present
    end

    it "leaves marketing_consent_at nil when marketing_consent is false" do
      user = create_user(marketing_consent: false)
      expect(user.marketing_consent_at).to be_nil
    end

    it "leaves marketing_consent_at nil when marketing_consent is omitted" do
      user = create_user
      expect(user.marketing_consent_at).to be_nil
    end
  end
end
