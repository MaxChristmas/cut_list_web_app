require "rails_helper"

RSpec.describe GuestLimits do
  include ActiveSupport::Testing::TimeHelpers
  describe ".has_feature?" do
    it "uses the free plan configuration" do
      expect(described_class::PLAN_CONFIG).to eq(Plannable::PLANS["free"])
    end

    it "allows pdf_export" do
      expect(described_class.has_feature?(:pdf_export)).to be true
    end

    it "allows label_pieces" do
      expect(described_class.has_feature?(:label_pieces)).to be true
    end

    it "allows cut_direction" do
      expect(described_class.has_feature?(:cut_direction)).to be true
    end

    it "denies blade_kerf" do
      expect(described_class.has_feature?(:blade_kerf)).to be false
    end

    it "denies import_csv" do
      expect(described_class.has_feature?(:import_csv)).to be false
    end
  end

  describe ".daily_count_for" do
    let(:project) { Project.create!(name: "Guest Project") }

    it "returns 0 for a project with no optimizations" do
      expect(described_class.daily_count_for(project.token)).to eq(0)
    end

    it "returns 0 for an unknown token" do
      expect(described_class.daily_count_for("nonexistent")).to eq(0)
    end

    it "does not count the initial optimization for a project created today" do
      project.optimizations.create!(status: "completed", result: {})
      expect(described_class.daily_count_for(project.token)).to eq(0)
    end

    it "counts additional optimizations beyond the first one" do
      5.times { project.optimizations.create!(status: "completed", result: {}) }
      expect(described_class.daily_count_for(project.token)).to eq(4)
    end

    it "reaches the free plan limit at 10 additional optimizations" do
      max = Plannable::PLANS["free"][:max_daily_optimizations_per_project]
      (max + 1).times { project.optimizations.create!(status: "completed", result: {}) }
      expect(described_class.daily_count_for(project.token)).to eq(max)
    end

    it "does not count optimizations from previous days" do
      travel_to 1.day.ago do
        5.times { project.optimizations.create!(status: "completed", result: {}) }
      end

      expect(described_class.daily_count_for(project.token)).to eq(0)
    end
  end

  describe ".guest_tokens" do
    it "returns an empty array when no tokens in session" do
      expect(described_class.guest_tokens({})).to eq([])
    end

    it "returns tokens from session" do
      session = { guest_project_tokens: ["abc123", "def456"] }
      expect(described_class.guest_tokens(session)).to eq(["abc123", "def456"])
    end
  end
end
