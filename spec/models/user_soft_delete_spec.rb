require "rails_helper"

RSpec.describe User, "#soft_delete!", type: :model do
  def create_user(overrides = {})
    User.create!({
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true
    }.merge(overrides))
  end

  it "sets discarded_at" do
    user = create_user
    user.soft_delete!
    expect(user.reload.discarded_at).to be_present
  end

  it "anonymizes the email" do
    user = create_user
    user.soft_delete!
    expect(user.reload.email).to eq("deleted-#{user.id}@anonymized.local")
  end

  it "clears provider and uid" do
    user = create_user(provider: "google_oauth2", uid: "123456")
    user.soft_delete!
    user.reload
    expect(user.provider).to be_nil
    expect(user.uid).to be_nil
  end

  it "clears stripe identifiers" do
    user = create_user
    user.update_columns(stripe_customer_id: "cus_123", stripe_subscription_id: "sub_456")
    user.soft_delete!
    user.reload
    expect(user.stripe_customer_id).to be_nil
    expect(user.stripe_subscription_id).to be_nil
  end

  it "locks the account" do
    user = create_user
    user.soft_delete!
    expect(user.reload.locked_at).to be_present
  end

  it "clears tracking fields" do
    user = create_user
    user.update_columns(
      last_sign_in_ip: "1.2.3.4",
      last_sign_in_city: "Paris",
      last_sign_in_country: "FR",
      last_sign_in_device: "desktop"
    )
    user.soft_delete!
    user.reload
    expect(user.last_sign_in_ip).to be_nil
    expect(user.last_sign_in_city).to be_nil
    expect(user.last_sign_in_country).to be_nil
    expect(user.last_sign_in_device).to be_nil
  end

  it "preserves associated projects" do
    user = create_user
    project = user.projects.create!(sheet_width: 100, sheet_length: 200)
    user.soft_delete!
    expect(project.reload).to be_persisted
    expect(project.user_id).to eq(user.id)
  end

  describe "#discarded?" do
    it "returns false for active users" do
      user = create_user
      expect(user.discarded?).to be false
    end

    it "returns true for soft-deleted users" do
      user = create_user
      user.soft_delete!
      expect(user.discarded?).to be true
    end
  end

  describe "scopes" do
    it ".kept returns only active users" do
      active = create_user(email: "active@example.com")
      discarded = create_user(email: "discarded@example.com")
      discarded.soft_delete!

      expect(User.kept).to include(active)
      expect(User.kept).not_to include(discarded)
    end

    it ".discarded returns only soft-deleted users" do
      active = create_user(email: "active@example.com")
      discarded = create_user(email: "discarded@example.com")
      discarded.soft_delete!

      expect(User.discarded).not_to include(active)
      expect(User.discarded).to include(discarded)
    end
  end
end
