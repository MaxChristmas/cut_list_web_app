require "rails_helper"

RSpec.describe "Admin::Users", type: :request do
  let(:admin_password) { "adminpass123" }

  let(:admin_user) do
    AdminUser.create!(
      email: "admin@example.com",
      password: admin_password,
      password_confirmation: admin_password
    )
  end

  def sign_in_admin
    post admin_user_session_path, params: {
      admin_user: { email: admin_user.email, password: admin_password }
    }
  end

  def create_user(overrides = {})
    User.create!({
      email: "testuser@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true
    }.merge(overrides))
  end

  describe "without authentication" do
    it "redirects to admin sign in" do
      get admin_users_path
      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  describe "with authentication" do
    before { sign_in_admin }

    describe "GET /admin/users" do
      it "returns success" do
        get admin_users_path
        expect(response).to have_http_status(:ok)
      end

      it "shows soft deleted badge for discarded users" do
        user = create_user
        user.soft_delete!
        get admin_users_path
        expect(response.body).to include("Soft Deleted")
      end
    end

    describe "GET /admin/users/:id" do
      it "shows user details" do
        user = create_user
        get admin_user_path(user)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("testuser@example.com")
      end

      it "shows soft deleted badge for discarded user" do
        user = create_user
        user.soft_delete!
        get admin_user_path(user)
        expect(response.body).to include("Soft Deleted")
      end

      it "hides soft delete button for already discarded user" do
        user = create_user
        user.soft_delete!
        get admin_user_path(user)
        expect(response.body).not_to include("Soft Delete</a>")
      end

      it "shows both delete buttons for active user" do
        user = create_user
        get admin_user_path(user)
        expect(response.body).to include("Soft Delete")
        expect(response.body).to include("Hard Delete")
      end
    end

    describe "PATCH /admin/users/:id/soft_delete" do
      it "anonymizes the user" do
        user = create_user
        patch soft_delete_admin_user_path(user)

        user.reload
        expect(user.discarded_at).to be_present
        expect(user.email).to eq("deleted-#{user.id}@anonymized.local")
        expect(user.locked_at).to be_present
      end

      it "redirects to the user show page" do
        user = create_user
        patch soft_delete_admin_user_path(user)
        expect(response).to redirect_to(admin_user_path(user))
      end

      it "sets a flash notice" do
        user = create_user
        patch soft_delete_admin_user_path(user)
        follow_redirect!
        expect(response.body).to include("soft deleted and anonymized")
      end
    end

    describe "DELETE /admin/users/:id (hard delete)" do
      it "permanently deletes the user" do
        user = create_user

        expect {
          delete admin_user_path(user)
        }.to change(User, :count).by(-1)
      end

      it "redirects to users index" do
        user = create_user
        delete admin_user_path(user)
        expect(response).to redirect_to(admin_users_path)
      end

      it "nullifies associated projects" do
        user = create_user
        project = user.projects.create!(sheet_width: 100, sheet_length: 200)

        delete admin_user_path(user)

        expect(project.reload.user_id).to be_nil
      end
    end
  end
end
