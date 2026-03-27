require "rails_helper"

RSpec.describe Feedback, type: :model do
  def create_user(overrides = {})
    User.create!({
      email: "feedback-model-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true
    }.merge(overrides))
  end

  def build_feedback(overrides = {})
    user = overrides.delete(:user) || create_user
    Feedback.new({ rating: 4, user: user }.merge(overrides))
  end

  # ──────────────────────────────────────────────
  # Associations
  # ──────────────────────────────────────────────

  describe "associations" do
    it "belongs to a user" do
      association = described_class.reflect_on_association(:user)
      expect(association.macro).to eq(:belongs_to)
    end

    it "requires a user" do
      feedback = Feedback.new(rating: 3, user: nil)
      expect(feedback).not_to be_valid
      expect(feedback.errors[:user]).to be_present
    end
  end

  # ──────────────────────────────────────────────
  # Validations
  # ──────────────────────────────────────────────

  describe "validations" do
    it "is valid with valid attributes" do
      expect(build_feedback).to be_valid
    end

    describe "rating" do
      it "requires a rating" do
        expect(build_feedback(rating: nil)).not_to be_valid
      end

      it "is valid with rating 1" do
        expect(build_feedback(rating: 1)).to be_valid
      end

      it "is valid with rating 5" do
        expect(build_feedback(rating: 5)).to be_valid
      end

      it "is valid with rating 3" do
        expect(build_feedback(rating: 3)).to be_valid
      end

      it "is invalid with rating 0" do
        expect(build_feedback(rating: 0)).not_to be_valid
      end

      it "is invalid with rating 6" do
        expect(build_feedback(rating: 6)).not_to be_valid
      end

      it "is invalid with a negative rating" do
        expect(build_feedback(rating: -1)).not_to be_valid
      end
    end

    describe "user uniqueness" do
      it "prevents a user from submitting feedback twice" do
        user = create_user
        Feedback.create!(rating: 4, user: user)

        duplicate = Feedback.new(rating: 5, user: user)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_id]).to be_present
      end

      it "allows different users to each submit feedback" do
        user_a = create_user
        user_b = create_user

        Feedback.create!(rating: 4, user: user_a)

        second = Feedback.new(rating: 2, user: user_b)
        expect(second).to be_valid
      end
    end
  end
end
