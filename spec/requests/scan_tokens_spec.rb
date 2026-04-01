require "rails_helper"

RSpec.describe "ScanTokens", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:password) { "password123" }

  def create_user(plan: "worker")
    User.create!(
      email: "scan-req-#{SecureRandom.hex(4)}@example.com",
      password: password,
      password_confirmation: password,
      terms_accepted: true,
      plan: plan
    )
  end

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: password } }
  end

  # ──────────────────────────────────────────────
  # POST /scan_tokens
  # ──────────────────────────────────────────────

  describe "POST /scan_tokens" do
    context "when not authenticated" do
      it "redirects to sign in" do
        post scan_tokens_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated as a free-plan user" do
      let(:user) { create_user(plan: "free") }

      before { sign_in(user) }

      it "returns 403 Forbidden" do
        post scan_tokens_path
        expect(response).to have_http_status(:forbidden)
      end

      it "does not create a ScanToken" do
        expect { post scan_tokens_path }.not_to change(ScanToken, :count)
      end
    end

    context "when authenticated as a worker-plan user" do
      let(:user) { create_user(plan: "worker") }

      before { sign_in(user) }

      it "returns 200 OK" do
        post scan_tokens_path
        expect(response).to have_http_status(:ok)
      end

      it "creates a new ScanToken" do
        expect { post scan_tokens_path }.to change(ScanToken, :count).by(1)
      end

      it "returns HTML containing a QR code (SVG)" do
        post scan_tokens_path
        expect(response.body).to include("svg")
      end

      it "returns HTML containing the scan token value" do
        post scan_tokens_path
        token = ScanToken.last
        expect(response.body).to include(token.token)
      end

      it "expires previous pending tokens for the same user" do
        old_token = user.scan_tokens.create!(status: "pending", expires_at: 5.minutes.from_now)

        post scan_tokens_path

        expect(old_token.reload.status).to eq("expired")
      end

      it "does not expire tokens from another user" do
        other_user = create_user
        other_token = other_user.scan_tokens.create!(status: "pending", expires_at: 5.minutes.from_now)

        sign_in(user)
        post scan_tokens_path

        expect(other_token.reload.status).to eq("pending")
      end

      it "does not expire already-completed tokens" do
        completed_token = user.scan_tokens.create!(
          status: "completed",
          expires_at: 1.day.from_now
        )

        post scan_tokens_path

        expect(completed_token.reload.status).to eq("completed")
      end

      it "does not expire already-expired tokens" do
        expired_token = user.scan_tokens.create!(
          status: "expired",
          expires_at: 1.day.from_now
        )

        post scan_tokens_path

        expect(expired_token.reload.status).to eq("expired")
      end

      context "with a project_token param" do
        let(:project) { user.projects.create!(name: "Test Project") }

        it "associates the scan token with the project" do
          post scan_tokens_path, params: { project_token: project.token }

          scan_token = ScanToken.last
          expect(scan_token.project).to eq(project)
        end
      end

      context "with an invalid project_token param" do
        it "creates the scan token without a project" do
          post scan_tokens_path, params: { project_token: "nonexistent" }

          scan_token = ScanToken.last
          expect(scan_token.project).to be_nil
        end
      end

      context "when the user has reached their monthly scan limit" do
        before do
          # Create enough completed scans to hit the worker limit (20)
          20.times do
            st = user.scan_tokens.create!(expires_at: 5.minutes.from_now)
            st.update_columns(status: "completed", created_at: Time.current.beginning_of_month + 1.day)
          end
        end

        it "returns unprocessable_entity" do
          post scan_tokens_path
          expect(response).to have_http_status(:unprocessable_content)
        end

        it "does not create a new ScanToken" do
          expect { post scan_tokens_path }.not_to change(ScanToken, :count)
        end
      end
    end

    context "when authenticated as an enterprise-plan user" do
      let(:user) { create_user(plan: "enterprise") }

      before { sign_in(user) }

      it "returns 200 OK" do
        post scan_tokens_path
        expect(response).to have_http_status(:ok)
      end

      it "creates a new ScanToken" do
        expect { post scan_tokens_path }.to change(ScanToken, :count).by(1)
      end
    end
  end

  # ──────────────────────────────────────────────
  # PATCH /scan_tokens/:id/submit_pieces
  # ──────────────────────────────────────────────

  describe "PATCH /scan_tokens/:id/submit_pieces" do
    let(:user) { create_user(plan: "worker") }

    let(:scan_token) { user.scan_tokens.create!(expires_at: 10.minutes.from_now) }

    # Pieces as they arrive from the browser (string values — HTTP params are strings)
    let(:pieces_params) do
      [
        { "nom" => "Côté", "longueur" => "750", "largeur" => "500", "quantite" => "2" },
        { "nom" => "Fond", "longueur" => "1200", "largeur" => "300", "quantite" => "1" }
      ]
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        patch submit_pieces_scan_token_path(scan_token), params: { pieces: pieces_params }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated" do
      before { sign_in(user) }

      it "returns 200 OK" do
        patch submit_pieces_scan_token_path(scan_token), params: { pieces: pieces_params }
        expect(response).to have_http_status(:ok)
      end

      it "saves submitted_pieces on the scan token" do
        patch submit_pieces_scan_token_path(scan_token), params: { pieces: pieces_params }
        saved = scan_token.reload.submitted_pieces
        expect(saved).to be_an(Array)
        expect(saved.size).to eq(2)
        expect(saved.first["nom"]).to eq("Côté")
      end

      it "allows overwriting previously submitted pieces" do
        scan_token.update!(submitted_pieces: [ { "nom" => "Old", "longueur" => 100, "largeur" => 50, "quantite" => 1 } ])

        patch submit_pieces_scan_token_path(scan_token), params: { pieces: pieces_params }

        saved = scan_token.reload.submitted_pieces
        expect(saved.first["nom"]).to eq("Côté")
      end

      it "does not update another user's scan token" do
        other_user = create_user
        other_token = other_user.scan_tokens.create!(expires_at: 10.minutes.from_now)

        # current_user.scan_tokens.find(other_id) raises RecordNotFound,
        # which Rails converts to a 404 in the request cycle
        begin
          patch submit_pieces_scan_token_path(other_token), params: { pieces: pieces_params }
          expect(response).to have_http_status(:not_found)
        rescue ActiveRecord::RecordNotFound
          # RecordNotFound is acceptable — the token is inaccessible
        end

        expect(other_token.reload.submitted_pieces).to be_nil
      end
    end
  end
end
