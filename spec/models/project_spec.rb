require "rails_helper"

RSpec.describe Project, type: :model do
  def create_user
    User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  describe "validations" do
    it "allows nil margin" do
      project = Project.new(name: "Test", margin: nil)
      project.valid?
      expect(project.errors[:margin]).to be_empty
    end

    it "allows zero margin" do
      project = Project.new(name: "Test", margin: 0)
      project.valid?
      expect(project.errors[:margin]).to be_empty
    end

    it "rejects negative margin" do
      project = Project.new(name: "Test", margin: -1)
      project.valid?
      expect(project.errors[:margin]).not_to be_empty
    end
  end

  describe "associations" do
    it "belongs to a user" do
      association = described_class.reflect_on_association(:user)
      expect(association.macro).to eq(:belongs_to)
    end

    it "does not require a user" do
      project = Project.create!(name: "Test", user: nil)
      expect(project).to be_valid
    end

    it "can be created with a user" do
      user = create_user
      project = Project.create!(name: "My Project", user: user)
      expect(project).to be_persisted
      expect(project.user).to eq(user)
    end
  end
end
