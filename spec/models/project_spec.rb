require "rails_helper"

RSpec.describe Project, type: :model do
  def create_user
    User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  describe "associations" do
    it "belongs to a user" do
      association = described_class.reflect_on_association(:user)
      expect(association.macro).to eq(:belongs_to)
    end

    it "requires a user" do
      project = Project.new(name: "Test", user: nil)
      expect(project).not_to be_valid
      expect(project.errors[:user]).to be_present
    end

    it "can be created with a user" do
      user = create_user
      project = Project.create!(name: "My Project", user: user)
      expect(project).to be_persisted
      expect(project.user).to eq(user)
    end
  end
end
