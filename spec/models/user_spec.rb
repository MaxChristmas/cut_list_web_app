require "rails_helper"

RSpec.describe User, type: :model do
  def build_user(overrides = {})
    User.new({
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    }.merge(overrides))
  end

  describe "default plan on first sign-up" do
    it "assigns the free plan to a new user" do
      user = build_user
      user.save!
      expect(user.plan).to eq("free")
    end

    it "limits to 2 active projects" do
      user = build_user
      user.save!
      expect(user.max_active_projects).to eq(2)
    end

    it "limits to 10 daily optimizations per project" do
      user = build_user
      user.save!
      expect(user.max_daily_optimizations_per_project).to eq(10)
    end
  end

  describe "validations" do
    it "is valid with valid attributes" do
      expect(build_user).to be_valid
    end

    it "requires an email" do
      expect(build_user(email: "")).not_to be_valid
    end

    it "requires a valid email format" do
      expect(build_user(email: "not-an-email")).not_to be_valid
    end

    it "requires a unique email" do
      build_user.save!
      duplicate = build_user(email: "test@example.com")
      expect(duplicate).not_to be_valid
    end

    it "requires a password" do
      expect(build_user(password: "", password_confirmation: "")).not_to be_valid
    end

    it "requires password to be at least 6 characters" do
      expect(build_user(password: "short", password_confirmation: "short")).not_to be_valid
    end
  end
end
