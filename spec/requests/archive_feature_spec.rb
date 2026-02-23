require "rails_helper"

RSpec.describe "Archive feature restriction", type: :request do
  let(:optimization_result) do
    { "sheets" => [], "efficiency" => 85.0, "total_sheets" => 1 }
  end

  def create_user(plan:)
    User.create!(
      email: "archive-#{plan}-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true,
      plan: plan
    )
  end

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end

  describe "free plan user" do
    let(:user) { create_user(plan: "free") }
    let(:project) { user.projects.create!(name: "My Project") }

    before { sign_in user }

    it "cannot archive a project" do
      patch archive_project_path(project.token)

      expect(response).to redirect_to(project_path(project.token))
      expect(flash[:alert]).to eq(I18n.t("limits.feature_not_available"))
      expect(project.reload.archived_at).to be_nil
    end

    it "cannot unarchive a project" do
      project.update!(archived_at: Time.current)

      patch unarchive_project_path(project.token)

      expect(response).to redirect_to(project_path(project.token))
      expect(flash[:alert]).to eq(I18n.t("limits.feature_not_available"))
      expect(project.reload.archived_at).to be_present
    end

    it "does not have the archive feature" do
      expect(user.has_feature?(:archive)).to be false
    end
  end

  describe "worker plan user" do
    let(:user) { create_user(plan: "worker") }
    let(:project) { user.projects.create!(name: "My Project") }

    before { sign_in user }

    it "cannot archive a project" do
      patch archive_project_path(project.token)

      expect(response).to redirect_to(project_path(project.token))
      expect(flash[:alert]).to eq(I18n.t("limits.feature_not_available"))
      expect(project.reload.archived_at).to be_nil
    end

    it "does not have the archive feature" do
      expect(user.has_feature?(:archive)).to be false
    end
  end

  describe "enterprise plan user" do
    let(:user) { create_user(plan: "enterprise") }
    let(:project) { user.projects.create!(name: "My Project") }

    before { sign_in user }

    it "can archive a project" do
      patch archive_project_path(project.token)

      expect(response).to redirect_to(root_path)
      expect(project.reload.archived_at).to be_present
    end

    it "can unarchive a project" do
      project.update!(archived_at: Time.current)

      patch unarchive_project_path(project.token)

      expect(response).to redirect_to(project_path(project.token))
      expect(project.reload.archived_at).to be_nil
    end

    it "has the archive feature" do
      expect(user.has_feature?(:archive)).to be true
    end
  end
end
