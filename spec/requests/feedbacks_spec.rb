require "rails_helper"

RSpec.describe "Feedbacks", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:password) { "password123" }

  def create_user(overrides = {})
    User.create!({
      email: "feedback-req-#{SecureRandom.hex(4)}@example.com",
      password: password,
      password_confirmation: password,
      terms_accepted: true
    }.merge(overrides))
  end

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: password } }
  end

  # ──────────────────────────────────────────────
  # POST /feedbacks
  # ──────────────────────────────────────────────

  describe "POST /feedbacks" do
    context "when not authenticated" do
      it "redirects to sign in" do
        post feedbacks_path, params: { feedback: { rating: 4 } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated" do
      let(:user) { create_user }

      before { sign_in(user) }

      context "with valid params" do
        it "returns 201 Created" do
          post feedbacks_path, params: { feedback: { rating: 4 } }
          expect(response).to have_http_status(:created)
        end

        it "creates a feedback record" do
          expect {
            post feedbacks_path, params: { feedback: { rating: 4 } }
          }.to change(Feedback, :count).by(1)
        end

        it "returns the new feedback id as JSON" do
          post feedbacks_path, params: { feedback: { rating: 5 } }
          body = JSON.parse(response.body)
          expect(body["id"]).to eq(Feedback.last.id)
        end

        it "saves optional improvement text" do
          post feedbacks_path, params: { feedback: { rating: 3, improvement: "Better export options" } }
          expect(Feedback.last.improvement).to eq("Better export options")
        end

        it "saves optional feature_request text" do
          post feedbacks_path, params: { feedback: { rating: 4, feature_request: "PDF export" } }
          expect(Feedback.last.feature_request).to eq("PDF export")
        end

        it "associates the feedback with the current user" do
          post feedbacks_path, params: { feedback: { rating: 4 } }
          expect(Feedback.last.user_id).to eq(user.id)
        end
      end

      context "with invalid params" do
        it "returns 422 Unprocessable Entity when rating is missing" do
          post feedbacks_path, params: { feedback: { rating: nil } }
          expect(response).to have_http_status(:unprocessable_content)
        end

        it "returns 422 Unprocessable Entity when rating is out of range" do
          post feedbacks_path, params: { feedback: { rating: 6 } }
          expect(response).to have_http_status(:unprocessable_content)
        end

        it "does not create a feedback record when invalid" do
          expect {
            post feedbacks_path, params: { feedback: { rating: nil } }
          }.not_to change(Feedback, :count)
        end

        it "returns 422 when the user has already submitted feedback" do
          Feedback.create!(user: user, rating: 3)

          post feedbacks_path, params: { feedback: { rating: 5 } }
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end
  end

  # ──────────────────────────────────────────────
  # PATCH /feedbacks/:id
  # ──────────────────────────────────────────────

  describe "PATCH /feedbacks/:id" do
    context "when not authenticated" do
      it "redirects to sign in" do
        user = create_user
        feedback = Feedback.create!(user: user, rating: 3)

        patch feedback_path(feedback), params: { feedback: { rating: 5 } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated" do
      let(:user) { create_user }
      let!(:feedback) { Feedback.create!(user: user, rating: 3) }

      before { sign_in(user) }

      it "returns 200 OK with valid params" do
        patch feedback_path(feedback), params: { feedback: { rating: 5 } }
        expect(response).to have_http_status(:ok)
      end

      it "updates the rating" do
        patch feedback_path(feedback), params: { feedback: { rating: 5 } }
        expect(feedback.reload.rating).to eq(5)
      end

      it "updates the improvement text" do
        patch feedback_path(feedback), params: { feedback: { rating: 3, improvement: "Faster optimization" } }
        expect(feedback.reload.improvement).to eq("Faster optimization")
      end

      it "updates the feature_request text" do
        patch feedback_path(feedback), params: { feedback: { rating: 4, feature_request: "Dark mode" } }
        expect(feedback.reload.feature_request).to eq("Dark mode")
      end

      it "returns 422 Unprocessable Entity when rating is out of range" do
        patch feedback_path(feedback), params: { feedback: { rating: 0 } }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "does not change the record on invalid update" do
        patch feedback_path(feedback), params: { feedback: { rating: 0 } }
        expect(feedback.reload.rating).to eq(3)
      end

      context "when trying to update another user's feedback" do
        let(:other_user) { create_user }
        let!(:other_feedback) { Feedback.create!(user: other_user, rating: 4) }

        it "raises RecordNotFound or returns 404" do
          begin
            patch feedback_path(other_feedback), params: { feedback: { rating: 1 } }
            expect(response).to have_http_status(:not_found)
          rescue ActiveRecord::RecordNotFound
            # scoped find on current_user.feedbacks raises RecordNotFound — acceptable
          end

          expect(other_feedback.reload.rating).to eq(4)
        end
      end
    end
  end

  # ──────────────────────────────────────────────
  # POST /feedbacks/dismiss
  # ──────────────────────────────────────────────

  describe "POST /feedbacks/dismiss" do
    context "when not authenticated" do
      it "redirects to sign in" do
        post dismiss_feedbacks_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated" do
      let(:user) { create_user }

      before { sign_in(user) }

      it "returns 200 OK" do
        post dismiss_feedbacks_path
        expect(response).to have_http_status(:ok)
      end

      it "sets feedback_dismissed_at on the current user" do
        freeze_time do
          post dismiss_feedbacks_path
          expect(user.reload.feedback_dismissed_at).to be_within(1.second).of(Time.current)
        end
      end

      it "does not affect other users" do
        other_user = create_user

        post dismiss_feedbacks_path

        expect(other_user.reload.feedback_dismissed_at).to be_nil
      end

      it "updates feedback_dismissed_at when called again" do
        user.update!(feedback_dismissed_at: 1.day.ago)

        freeze_time do
          post dismiss_feedbacks_path
          expect(user.reload.feedback_dismissed_at).to be_within(1.second).of(Time.current)
        end
      end
    end
  end
end
