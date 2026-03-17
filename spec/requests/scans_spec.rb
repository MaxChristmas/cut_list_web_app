require "rails_helper"

RSpec.describe "Scans", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  def create_user(plan: "worker")
    User.create!(
      email: "scans-req-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true,
      plan: plan
    )
  end

  let(:user) { create_user }
  let(:valid_token) { user.scan_tokens.create!(expires_at: 10.minutes.from_now) }

  # A real 1×1 PNG fixture — small enough to skip compression in the service
  def test_image_upload(content_type: "image/png", filename: "test_photo.png")
    fixture_file_upload(
      Rails.root.join("spec/fixtures/files/test_photo.png"),
      content_type
    )
  end

  def stub_photo_extractor(pieces: nil, image_type: "liste")
    pieces ||= [
      { "nom" => "Côté", "longueur" => 750, "largeur" => 500, "quantite" => 2 }
    ]
    result = {
      "pieces" => pieces,
      "image_type" => image_type,
      "input_tokens" => 100,
      "output_tokens" => 50,
      "cost_usd" => 0.001
    }
    service_double = instance_double(PhotoPieceExtractorService, call: result)
    allow(PhotoPieceExtractorService).to receive(:new).and_return(service_double)
    service_double
  end

  def stub_turbo_broadcasts
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
  end

  # ──────────────────────────────────────────────
  # GET /scan/:token  (show)
  # ──────────────────────────────────────────────

  describe "GET /scan/:token" do
    context "with a valid, usable token" do
      it "returns 200 OK" do
        get scan_path(valid_token.token)
        expect(response).to have_http_status(:ok)
      end

      it "renders the camera page (no error)" do
        get scan_path(valid_token.token)
        expect(response.body).to include(I18n.t("scan.title"))
      end

      it "does not render the expired error" do
        get scan_path(valid_token.token)
        expect(response.body).not_to include(I18n.t("scan.expired_title"))
      end
    end

    context "with an unknown token" do
      it "returns 200 OK but renders error state" do
        get scan_path("this_token_does_not_exist")
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("scan.expired_title"))
      end
    end

    context "with an expired token (time-based)" do
      it "renders the error state" do
        expired = user.scan_tokens.create!(expires_at: 1.second.ago)
        get scan_path(expired.token)
        expect(response.body).to include(I18n.t("scan.expired_title"))
      end
    end

    context "with a token in processing status" do
      it "renders the error state" do
        valid_token.update!(status: "processing")
        get scan_path(valid_token.token)
        expect(response.body).to include(I18n.t("scan.expired_title"))
      end
    end

    context "with a completed token" do
      it "renders the error state" do
        valid_token.update!(status: "completed")
        get scan_path(valid_token.token)
        expect(response.body).to include(I18n.t("scan.expired_title"))
      end
    end
  end

  # ──────────────────────────────────────────────
  # POST /scan/:token/upload
  # ──────────────────────────────────────────────

  describe "POST /scan/:token/upload" do
    context "with a valid token and a valid image" do
      before do
        stub_photo_extractor
        stub_turbo_broadcasts
      end

      it "returns 200 OK" do
        post scan_upload_path(valid_token.token), params: { photo: test_image_upload }
        expect(response).to have_http_status(:ok)
      end

      it "renders the upload_success template" do
        post scan_upload_path(valid_token.token), params: { photo: test_image_upload }
        expect(response.body).to include(I18n.t("scan.success_title"))
      end

      it "marks the scan token as completed" do
        post scan_upload_path(valid_token.token), params: { photo: test_image_upload }
        expect(valid_token.reload.status).to eq("completed")
      end

      it "stores the extracted pieces in result" do
        post scan_upload_path(valid_token.token), params: { photo: test_image_upload }
        result = valid_token.reload.result
        expect(result).to be_an(Array)
        expect(result.first).to include("longueur", "largeur", "quantite")
      end

      it "saves image_type on the scan token" do
        post scan_upload_path(valid_token.token), params: { photo: test_image_upload }
        expect(valid_token.reload.image_type).to eq("liste")
      end

      it "saves token usage (input_tokens, output_tokens, cost_usd)" do
        post scan_upload_path(valid_token.token), params: { photo: test_image_upload }
        scan = valid_token.reload
        expect(scan.input_tokens).to eq(100)
        expect(scan.output_tokens).to eq(50)
        expect(scan.cost_usd).to eq(0.001)
      end

      it "merges duplicate pieces" do
        stub_photo_extractor(pieces: [
          { "nom" => "A", "longueur" => 500, "largeur" => 300, "quantite" => 1 },
          { "nom" => "B", "longueur" => 500, "largeur" => 300, "quantite" => 1 }
        ])

        post scan_upload_path(valid_token.token), params: { photo: test_image_upload }

        result = valid_token.reload.result
        expect(result.size).to eq(1)
        expect(result.first["quantite"]).to eq(2)
      end

      it "normalizes pieces so longueur >= largeur" do
        stub_photo_extractor(pieces: [
          { "nom" => "Side", "longueur" => 300, "largeur" => 700, "quantite" => 1 }
        ])

        post scan_upload_path(valid_token.token), params: { photo: test_image_upload }

        piece = valid_token.reload.result.first
        expect(piece["longueur"]).to be >= piece["largeur"]
      end

      it "broadcasts analyzing state then result via Turbo" do
        expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).at_least(2).times
        post scan_upload_path(valid_token.token), params: { photo: test_image_upload }
      end
    end

    context "with an expired token (time-based)" do
      it "renders the upload_error template with expiry message" do
        expired = user.scan_tokens.create!(expires_at: 1.second.ago)
        post scan_upload_path(expired.token), params: { photo: test_image_upload }
        expect(response.body).to include(I18n.t("scan.expired_title"))
      end

      it "does not call the extractor service" do
        expect(PhotoPieceExtractorService).not_to receive(:new)
        expired = user.scan_tokens.create!(expires_at: 1.second.ago)
        post scan_upload_path(expired.token), params: { photo: test_image_upload }
      end
    end

    context "with a processing token" do
      it "renders the upload_error template with expiry message" do
        valid_token.update!(status: "processing")
        post scan_upload_path(valid_token.token), params: { photo: test_image_upload }
        expect(response.body).to include(I18n.t("scan.expired_title"))
      end
    end

    context "with an unknown token" do
      it "renders the upload_error template with expiry message" do
        post scan_upload_path("nonexistent_token"), params: { photo: test_image_upload }
        expect(response.body).to include(I18n.t("scan.expired_title"))
      end
    end

    context "with no photo param" do
      it "renders the upload_error template" do
        post scan_upload_path(valid_token.token)
        expect(response.body).to include(I18n.t("scan.no_photo"))
      end

      it "does not call the extractor service" do
        expect(PhotoPieceExtractorService).not_to receive(:new)
        post scan_upload_path(valid_token.token)
      end
    end

    context "with a non-image file" do
      it "renders the upload_error template" do
        pdf_content = "%PDF-1.4 fake content"
        pdf_tempfile = Tempfile.new([ "fake_doc", ".pdf" ])
        pdf_tempfile.write(pdf_content)
        pdf_tempfile.rewind
        pdf_file = Rack::Test::UploadedFile.new(pdf_tempfile.path, "application/pdf", true)

        post scan_upload_path(valid_token.token), params: { photo: pdf_file }
        expect(response.body).to include(I18n.t("scan.invalid_file_type"))
      end
    end

    context "with a file exceeding 10 MB" do
      it "renders the upload_error template" do
        large_tempfile = Tempfile.new([ "large_image", ".jpg" ])
        large_tempfile.binmode
        large_tempfile.write("x" * (10.megabytes + 1))
        large_tempfile.rewind
        large_file = Rack::Test::UploadedFile.new(large_tempfile.path, "image/jpeg", true)

        post scan_upload_path(valid_token.token), params: { photo: large_file }
        expect(response.body).to include(I18n.t("scan.file_too_large"))
      end

      it "does not call the extractor service" do
        expect(PhotoPieceExtractorService).not_to receive(:new)

        large_tempfile = Tempfile.new([ "large_image2", ".jpg" ])
        large_tempfile.binmode
        large_tempfile.write("x" * (10.megabytes + 1))
        large_tempfile.rewind
        large_file = Rack::Test::UploadedFile.new(large_tempfile.path, "image/jpeg", true)

        post scan_upload_path(valid_token.token), params: { photo: large_file }
      end
    end

    context "when the extractor service raises an error" do
      before do
        allow(PhotoPieceExtractorService).to receive(:new).and_raise(StandardError, "API error")
        stub_turbo_broadcasts
      end

      it "renders the upload_error template" do
        post scan_upload_path(valid_token.token), params: { photo: test_image_upload }
        expect(response.body).to include(I18n.t("scan.analysis_failed"))
      end

      it "resets the scan token status back to pending" do
        post scan_upload_path(valid_token.token), params: { photo: test_image_upload }
        expect(valid_token.reload.status).to eq("pending")
      end

      it "broadcasts an error state to the desktop" do
        expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).at_least(:once)
        post scan_upload_path(valid_token.token), params: { photo: test_image_upload }
      end
    end
  end
end
