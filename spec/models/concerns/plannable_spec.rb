require "rails_helper"

RSpec.describe Plannable, type: :model do
  include ActiveSupport::Testing::TimeHelpers
  def create_user(plan: "free")
    User.create!(
      email: "plannable-test-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      plan: plan
    )
  end

  def create_project(user:)
    user.projects.create!(name: "Project #{SecureRandom.hex(4)}")
  end

  describe "free plan limits" do
    let(:user) { create_user(plan: "free") }

    describe "#max_active_projects" do
      it "allows 2 active projects" do
        expect(user.max_active_projects).to eq(2)
      end
    end

    describe "#max_monthly_optimizations_per_project" do
      it "allows 10 monthly optimizations per project" do
        expect(user.max_monthly_optimizations_per_project).to eq(10)
      end
    end

    describe "#can_create_project?" do
      it "allows creating a project when under the limit" do
        expect(user.can_create_project?).to be true
      end

      it "allows creating a second project" do
        create_project(user: user)
        expect(user.can_create_project?).to be true
      end

      it "denies creating a third project" do
        2.times { create_project(user: user) }
        expect(user.can_create_project?).to be false
      end

      it "does not count archived projects toward the limit" do
        2.times { create_project(user: user) }
        user.projects.first.update!(archived_at: Time.current)

        expect(user.can_create_project?).to be true
      end
    end

    describe "#can_run_optimization?" do
      let(:project) { create_project(user: user) }

      it "allows running an optimization on a new project" do
        expect(user.can_run_optimization?(project)).to be true
      end

      it "does not count the initial optimization (created with the project this month)" do
        project.optimizations.create!(status: "completed", result: {})
        expect(user.monthly_optimizations_count_for(project)).to eq(0)
      end

      it "allows up to 10 additional optimizations per month" do
        # The first optimization is free (created with the project)
        11.times { project.optimizations.create!(status: "completed", result: {}) }

        expect(user.monthly_optimizations_count_for(project)).to eq(10)
        expect(user.can_run_optimization?(project)).to be false
      end

      it "allows the 10th optimization but denies the 11th" do
        # 1 initial + 10 additional = 11 total, count = 10
        10.times { project.optimizations.create!(status: "completed", result: {}) }
        expect(user.monthly_optimizations_count_for(project)).to eq(9)
        expect(user.can_run_optimization?(project)).to be true

        project.optimizations.create!(status: "completed", result: {})
        expect(user.monthly_optimizations_count_for(project)).to eq(10)
        expect(user.can_run_optimization?(project)).to be false
      end

      it "resets the count at the beginning of a new month" do
        # Create optimizations in the previous month
        travel_to 1.month.ago do
          11.times { project.optimizations.create!(status: "completed", result: {}) }
        end

        # In the current month, the count should be 0
        expect(user.monthly_optimizations_count_for(project)).to eq(0)
        expect(user.can_run_optimization?(project)).to be true
      end
    end

    describe "#has_feature?" do
      it "includes pdf_export" do
        expect(user.has_feature?(:pdf_export)).to be true
      end

      it "includes label_pieces" do
        expect(user.has_feature?(:label_pieces)).to be true
      end

      it "includes cut_direction" do
        expect(user.has_feature?(:cut_direction)).to be true
      end

      it "excludes blade_kerf" do
        expect(user.has_feature?(:blade_kerf)).to be false
      end

      it "excludes import_csv" do
        expect(user.has_feature?(:import_csv)).to be false
      end

      it "excludes archive" do
        expect(user.has_feature?(:archive)).to be false
      end
    end
  end

  describe "plan expiration" do
    it "falls back to free plan limits when plan expires" do
      user = create_user(plan: "worker")
      expect(user.max_active_projects).to eq(10)

      user.update!(plan_expires_at: 1.day.ago)
      expect(user.max_active_projects).to eq(2)
      expect(user.max_monthly_optimizations_per_project).to eq(10)
    end
  end
end
