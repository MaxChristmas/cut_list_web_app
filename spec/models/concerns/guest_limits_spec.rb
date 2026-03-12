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

    it "allows blade_kerf" do
      expect(described_class.has_feature?(:blade_kerf)).to be true
    end

    it "denies import_csv" do
      expect(described_class.has_feature?(:import_csv)).to be false
    end
  end

  describe ".guest_tokens" do
    it "returns an empty array when no tokens in session" do
      expect(described_class.guest_tokens({})).to eq([])
    end

    it "returns tokens from session" do
      session = { guest_project_tokens: [ "abc123", "def456" ] }
      expect(described_class.guest_tokens(session)).to eq([ "abc123", "def456" ])
    end
  end
end
