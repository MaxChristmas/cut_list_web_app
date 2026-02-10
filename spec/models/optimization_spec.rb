require "rails_helper"

RSpec.describe Optimization, type: :model do
  def create_project
    user = User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    Project.create!(name: "Test Project", user: user)
  end

  describe "associations" do
    it "belongs to a project" do
      association = described_class.reflect_on_association(:project)
      expect(association.macro).to eq(:belongs_to)
    end

    it "requires a project" do
      optimization = Optimization.new(project: nil)
      expect(optimization).not_to be_valid
      expect(optimization.errors[:project]).to be_present
    end

    it "can be created with a project" do
      project = create_project
      optimization = Optimization.create!(
        project: project,
        status: "completed",
        efficiency: 85.5,
        sheets_count: 3,
        result: { sheets: [] }
      )
      expect(optimization).to be_persisted
      expect(optimization.project).to eq(project)
    end
  end

  describe "attributes" do
    it "stores JSONB result" do
      project = create_project
      result_data = { "sheets" => [{ "cuts" => [] }] }
      optimization = Optimization.create!(project: project, result: result_data)
      optimization.reload
      expect(optimization.result).to eq(result_data)
    end
  end
end
