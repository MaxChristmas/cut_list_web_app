require "rails_helper"

RSpec.describe ScanToken, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  def create_user(plan: "worker")
    User.create!(
      email: "scan-token-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true,
      plan: plan
    )
  end

  let(:user) { create_user }

  def build_scan_token(overrides = {})
    user.scan_tokens.build(overrides)
  end

  def create_scan_token(overrides = {})
    user.scan_tokens.create!(overrides)
  end

  # ──────────────────────────────────────────────
  # Validations
  # ──────────────────────────────────────────────

  describe "validations" do
    it "is valid with default attributes" do
      token = build_scan_token
      expect(token).to be_valid
    end

    it "requires a token" do
      token = build_scan_token
      token.save! # generate_token runs on before_validation
      token.token = nil
      expect(token).not_to be_valid
      expect(token.errors[:token]).to be_present
    end

    it "requires a unique token" do
      existing = create_scan_token
      duplicate = build_scan_token(token: existing.token)
      # bypass generate_token by forcing a value
      duplicate.instance_variable_set(:@bypass_token_generation, true)
      expect(duplicate).not_to be_valid
    end

    it "requires a status" do
      token = create_scan_token
      token.status = nil
      expect(token).not_to be_valid
    end

    it "only accepts valid status values" do
      %w[pending processing completed expired].each do |s|
        token = create_scan_token
        token.status = s
        expect(token).to be_valid, "expected #{s} to be valid"
      end
    end

    it "rejects an invalid status value" do
      token = create_scan_token
      token.status = "unknown"
      expect(token).not_to be_valid
      expect(token.errors[:status]).to be_present
    end

    it "requires expires_at" do
      token = create_scan_token
      token.expires_at = nil
      expect(token).not_to be_valid
    end

    it "belongs to a user" do
      token = ScanToken.new(token: SecureRandom.urlsafe_base64(32), expires_at: 10.minutes.from_now, status: "pending")
      expect(token).not_to be_valid
      expect(token.errors[:user]).to be_present
    end

    it "allows an optional project" do
      token = build_scan_token
      expect(token).to be_valid
      expect(token.project).to be_nil
    end
  end

  # ──────────────────────────────────────────────
  # Token generation and expiry on create
  # ──────────────────────────────────────────────

  describe "before_validation callbacks on create" do
    it "generates a token automatically" do
      token = create_scan_token
      expect(token.token).to be_present
      expect(token.token.length).to be >= 32
    end

    it "does not override an existing token" do
      custom = "my_custom_token_value_abc123"
      token = create_scan_token(token: custom)
      expect(token.token).to eq(custom)
    end

    it "generates a URL-safe base64 token" do
      token = create_scan_token
      expect(token.token).to match(/\A[A-Za-z0-9\-_]+\z/)
    end

    it "sets expires_at to approximately 10 minutes from now" do
      freeze_time do
        token = create_scan_token
        expect(token.expires_at).to be_within(1.second).of(10.minutes.from_now)
      end
    end

    it "does not override a provided expires_at" do
      custom_expiry = 30.minutes.from_now
      token = create_scan_token(expires_at: custom_expiry)
      expect(token.expires_at).to be_within(1.second).of(custom_expiry)
    end

    it "generates unique tokens for concurrent creates" do
      tokens = 5.times.map { create_scan_token }
      expect(tokens.map(&:token).uniq.size).to eq(5)
    end
  end

  # ──────────────────────────────────────────────
  # Scopes
  # ──────────────────────────────────────────────

  describe ".valid_pending scope" do
    it "includes pending tokens that have not expired" do
      token = create_scan_token
      expect(ScanToken.valid_pending).to include(token)
    end

    it "excludes pending tokens that have expired" do
      token = create_scan_token(expires_at: 1.minute.ago)
      expect(ScanToken.valid_pending).not_to include(token)
    end

    it "excludes processing tokens" do
      token = create_scan_token
      token.update!(status: "processing")
      expect(ScanToken.valid_pending).not_to include(token)
    end

    it "excludes completed tokens" do
      token = create_scan_token
      token.update!(status: "completed")
      expect(ScanToken.valid_pending).not_to include(token)
    end

    it "excludes expired-status tokens" do
      token = create_scan_token
      token.update!(status: "expired")
      expect(ScanToken.valid_pending).not_to include(token)
    end
  end

  # ──────────────────────────────────────────────
  # Instance methods
  # ──────────────────────────────────────────────

  describe "#expired?" do
    it "returns false when expires_at is in the future" do
      token = create_scan_token
      expect(token.expired?).to be false
    end

    it "returns true when expires_at is in the past" do
      token = create_scan_token(expires_at: 1.second.ago)
      expect(token.expired?).to be true
    end

    it "is not expired exactly at the expiry boundary (expires_at uses strict <)" do
      freeze_time do
        # expires_at == Time.current → NOT expired because the check is `expires_at < Time.current`
        token = create_scan_token(expires_at: Time.current)
        expect(token.expired?).to be false
      end
    end
  end

  describe "#usable?" do
    it "returns true for a pending, non-expired token" do
      token = create_scan_token
      expect(token.usable?).to be true
    end

    it "returns false when status is processing" do
      token = create_scan_token
      token.update!(status: "processing")
      expect(token.usable?).to be false
    end

    it "returns false when status is completed" do
      token = create_scan_token
      token.update!(status: "completed")
      expect(token.usable?).to be false
    end

    it "returns false when status is expired" do
      token = create_scan_token
      token.update!(status: "expired")
      expect(token.usable?).to be false
    end

    it "returns false when token is pending but expired in time" do
      token = create_scan_token(expires_at: 1.second.ago)
      expect(token.usable?).to be false
    end
  end

  describe "#mark_processing!" do
    it "changes status to processing" do
      token = create_scan_token
      token.mark_processing!
      expect(token.reload.status).to eq("processing")
    end
  end

  describe "#mark_completed!" do
    let(:pieces) do
      [
        { "nom" => "Côté", "longueur" => 750, "largeur" => 500, "quantite" => 2 },
        { "nom" => "Fond", "longueur" => 1200, "largeur" => 300, "quantite" => 1 }
      ]
    end

    it "changes status to completed" do
      token = create_scan_token
      token.mark_completed!(pieces)
      expect(token.reload.status).to eq("completed")
    end

    it "saves the pieces as result" do
      token = create_scan_token
      token.mark_completed!(pieces)
      expect(token.reload.result).to eq(pieces)
    end
  end

  # ──────────────────────────────────────────────
  # pieces_modified?
  # ──────────────────────────────────────────────

  describe "#pieces_modified?" do
    let(:ai_pieces) do
      [
        { "nom" => "Côté", "longueur" => 750, "largeur" => 500, "quantite" => 2 },
        { "nom" => "Fond", "longueur" => 1200, "largeur" => 300, "quantite" => 1 }
      ]
    end

    it "returns false when result and submitted_pieces are identical" do
      token = create_scan_token
      token.update!(result: ai_pieces, submitted_pieces: ai_pieces)
      expect(token.pieces_modified?).to be false
    end

    it "returns true when submitted_pieces differ from result" do
      modified = [
        { "nom" => "Côté", "longueur" => 800, "largeur" => 500, "quantite" => 2 },
        { "nom" => "Fond", "longueur" => 1200, "largeur" => 300, "quantite" => 1 }
      ]
      token = create_scan_token
      token.update!(result: ai_pieces, submitted_pieces: modified)
      expect(token.pieces_modified?).to be true
    end

    it "returns true when quantity differs" do
      modified = [
        { "nom" => "Côté", "longueur" => 750, "largeur" => 500, "quantite" => 3 },
        { "nom" => "Fond", "longueur" => 1200, "largeur" => 300, "quantite" => 1 }
      ]
      token = create_scan_token
      token.update!(result: ai_pieces, submitted_pieces: modified)
      expect(token.pieces_modified?).to be true
    end

    it "returns false when result is blank" do
      token = create_scan_token
      token.update!(result: nil, submitted_pieces: ai_pieces)
      expect(token.pieces_modified?).to be false
    end

    it "returns false when submitted_pieces is blank" do
      token = create_scan_token
      token.update!(result: ai_pieces, submitted_pieces: nil)
      expect(token.pieces_modified?).to be false
    end

    it "handles the english key aliases (length/width/quantity)" do
      en_pieces = [
        { "label" => "Side", "length" => 750, "width" => 500, "quantity" => 2 }
      ]
      fr_pieces = [
        { "nom" => "Side", "longueur" => 750, "largeur" => 500, "quantite" => 2 }
      ]
      token = create_scan_token
      token.update!(result: en_pieces, submitted_pieces: fr_pieces)
      expect(token.pieces_modified?).to be false
    end
  end

  # ──────────────────────────────────────────────
  # accuracy_report
  # ──────────────────────────────────────────────

  describe "#accuracy_report" do
    let(:ai_pieces) do
      [
        { "nom" => "Côté", "longueur" => 750, "largeur" => 500, "quantite" => 2 },
        { "nom" => "Fond", "longueur" => 1200, "largeur" => 300, "quantite" => 1 }
      ]
    end

    it "returns nil when result is missing" do
      token = create_scan_token
      token.update!(result: nil, submitted_pieces: ai_pieces)
      expect(token.accuracy_report).to be_nil
    end

    it "returns nil when submitted_pieces is missing" do
      token = create_scan_token
      token.update!(result: ai_pieces, submitted_pieces: nil)
      expect(token.accuracy_report).to be_nil
    end

    it "returns a report hash with the expected keys" do
      token = create_scan_token
      token.update!(result: ai_pieces, submitted_pieces: ai_pieces)
      report = token.accuracy_report
      expect(report).to include(:ai_count, :user_count, :matched, :exact_matches, :close_matches, :wrong, :accuracy_pct)
    end

    it "reports 100% accuracy when pieces are identical" do
      token = create_scan_token
      token.update!(result: ai_pieces, submitted_pieces: ai_pieces)
      report = token.accuracy_report
      expect(report[:accuracy_pct]).to eq(100.0)
      expect(report[:exact_matches]).to eq(2)
      expect(report[:wrong]).to eq(0)
    end

    it "counts ai pieces correctly" do
      token = create_scan_token
      token.update!(result: ai_pieces, submitted_pieces: ai_pieces)
      expect(token.accuracy_report[:ai_count]).to eq(2)
    end

    it "counts user pieces correctly" do
      extra = ai_pieces + [ { "nom" => "Extra", "longueur" => 400, "largeur" => 200, "quantite" => 1 } ]
      token = create_scan_token
      token.update!(result: ai_pieces, submitted_pieces: extra)
      expect(token.accuracy_report[:user_count]).to eq(3)
    end

    it "identifies wrong matches when dimensions differ significantly" do
      very_different = [
        { "nom" => "Côté", "longueur" => 2000, "largeur" => 100, "quantite" => 1 },
        { "nom" => "Fond", "longueur" => 3000, "largeur" => 100, "quantite" => 1 }
      ]
      token = create_scan_token
      token.update!(result: ai_pieces, submitted_pieces: very_different)
      report = token.accuracy_report
      expect(report[:wrong]).to be > 0
    end

    it "lists unmatched ai pieces as removed_by_user" do
      one_piece = [ ai_pieces.first ]
      token = create_scan_token
      token.update!(result: ai_pieces, submitted_pieces: one_piece)
      report = token.accuracy_report
      expect(report[:removed_by_user].size).to eq(1)
    end
  end
end
