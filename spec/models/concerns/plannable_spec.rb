require "rails_helper"

RSpec.describe Plannable, type: :model do
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

  def create_optimization(project:, created_at: Time.current)
    opt = project.optimizations.new(status: "completed", result: {}, sheets_count: 1)
    opt.created_at = created_at
    opt.save!
    opt
  end

  describe "free plan limits" do
    let(:user) { create_user(plan: "free") }

    describe "#max_active_projects" do
      it "allows 2 active projects" do
        expect(user.max_active_projects).to eq(2)
      end
    end

    describe "#max_pieces_per_project" do
      it "allows 20 pieces per project" do
        expect(user.max_pieces_per_project).to eq(20)
      end
    end

    describe "#max_daily_optimizations" do
      it "allows 10 optimizations per day" do
        expect(user.max_daily_optimizations).to eq(10)
      end
    end

    describe "#can_create_project?" do
      it "allows creating a project when under the limit" do
        expect(user.can_create_project?).to be true
      end

      it "allows creating a project when at 1 active project" do
        1.times { create_project(user: user) }
        expect(user.can_create_project?).to be true
      end

      it "denies creating a project when at 2 active projects" do
        2.times { create_project(user: user) }
        expect(user.can_create_project?).to be false
      end

      it "does not count archived projects toward the limit" do
        2.times { create_project(user: user) }
        user.projects.first.update!(archived_at: Time.current)

        expect(user.can_create_project?).to be true
      end
    end

    describe "#can_optimize_today?" do
      it "returns true when under the daily limit" do
        project = create_project(user: user)
        5.times { create_optimization(project: project) }
        expect(user.can_optimize_today?).to be true
      end

      it "returns false when at the daily limit" do
        project = create_project(user: user)
        10.times { create_optimization(project: project) }
        expect(user.can_optimize_today?).to be false
      end

      it "does not count yesterday's optimizations" do
        project = create_project(user: user)
        10.times { create_optimization(project: project, created_at: 1.day.ago) }
        expect(user.can_optimize_today?).to be true
      end

      it "counts optimizations across all user projects" do
        project1 = create_project(user: user)
        project2 = create_project(user: user)
        5.times { create_optimization(project: project1) }
        5.times { create_optimization(project: project2) }
        expect(user.can_optimize_today?).to be false
      end
    end

    describe "#usage_daily_optimizations" do
      it "returns used count and max" do
        project = create_project(user: user)
        3.times { create_optimization(project: project) }
        usage = user.usage_daily_optimizations
        expect(usage[:used]).to eq(3)
        expect(usage[:max]).to eq(10)
      end
    end

    describe "#max_daily_pdf_exports" do
      it "returns 3" do
        expect(user.max_daily_pdf_exports).to eq(3)
      end
    end

    describe "#can_export_pdf_today?" do
      it "returns true when under the daily limit" do
        2.times { user.pdf_exports.create! }
        expect(user.can_export_pdf_today?).to be true
      end

      it "returns false when at the daily limit" do
        3.times { user.pdf_exports.create! }
        expect(user.can_export_pdf_today?).to be false
      end
    end

    describe "#usage_daily_pdf_exports" do
      it "returns used count and max" do
        2.times { user.pdf_exports.create! }
        usage = user.usage_daily_pdf_exports
        expect(usage[:used]).to eq(2)
        expect(usage[:max]).to eq(3)
      end
    end

    describe "#can_optimize_pieces?" do
      it "allows optimizing with 20 pieces or fewer" do
        pieces = [ { length: 100, width: 50, quantity: 20 } ]
        expect(user.can_optimize_pieces?(pieces)).to be true
      end

      it "denies optimizing with more than 20 pieces" do
        pieces = [ { length: 100, width: 50, quantity: 21 } ]
        expect(user.can_optimize_pieces?(pieces)).to be false
      end

      it "sums quantities across multiple piece lines" do
        pieces = [
          { length: 100, width: 50, quantity: 15 },
          { length: 200, width: 80, quantity: 11 }
        ]
        expect(user.can_optimize_pieces?(pieces)).to be false
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

      it "includes blade_kerf" do
        expect(user.has_feature?(:blade_kerf)).to be true
      end

      it "excludes import_csv" do
        expect(user.has_feature?(:import_csv)).to be false
      end

      it "excludes archive" do
        expect(user.has_feature?(:archive)).to be false
      end
    end
  end

  describe "worker plan" do
    let(:user) { create_user(plan: "worker") }

    it "has unlimited pieces per project" do
      expect(user.max_pieces_per_project).to eq(Float::INFINITY)
    end

    it "allows any number of pieces" do
      pieces = [ { length: 100, width: 50, quantity: 1000 } ]
      expect(user.can_optimize_pieces?(pieces)).to be true
    end

    describe "#max_daily_optimizations" do
      it "returns Float::INFINITY" do
        expect(user.max_daily_optimizations).to eq(Float::INFINITY)
      end
    end

    describe "#can_optimize_today?" do
      it "always returns true even with many optimizations" do
        project = create_project(user: user)
        20.times { create_optimization(project: project) }
        expect(user.can_optimize_today?).to be true
      end
    end

    describe "#max_daily_pdf_exports" do
      it "returns Float::INFINITY" do
        expect(user.max_daily_pdf_exports).to eq(Float::INFINITY)
      end
    end
  end

  describe "plan expiration" do
    it "falls back to free plan limits when plan expires" do
      user = create_user(plan: "worker")
      expect(user.max_active_projects).to eq(Float::INFINITY)

      user.update!(plan_expires_at: 1.day.ago)
      expect(user.max_active_projects).to eq(2)
      expect(user.max_pieces_per_project).to eq(20)
      expect(user.max_daily_optimizations).to eq(10)
      expect(user.max_daily_pdf_exports).to eq(3)
    end
  end
end
