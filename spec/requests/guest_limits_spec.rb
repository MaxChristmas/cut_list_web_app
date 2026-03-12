require "rails_helper"

RSpec.describe "Guest user limits", type: :request do
  describe "POST /projects (create)" do
    it "redirects logged-out users to root with signup prompt" do
      post projects_path, params: {
        name: "Test", stock_l: 2440, stock_w: 1220,
        pieces: [ { length: 500, width: 300, quantity: 1 } ]
      }

      expect(response).to redirect_to(root_path)
      expect(flash[:show_signup]).to be_present
    end
  end

  describe "PATCH /projects/:token (update / run optimization)" do
    let(:project) { Project.create!(name: "Guest Project") }

    it "redirects logged-out users with signup prompt" do
      patch project_path(project.token), params: {
        name: "Updated", stock_l: 2440, stock_w: 1220,
        pieces: [ { length: 500, width: 300, quantity: 1 } ]
      }

      expect(response).to redirect_to(project_path(project.token))
      expect(flash[:show_signup]).to be_present
    end
  end

  describe "pieces limit for free plan user" do
    let(:user) do
      User.create!(
        email: "free@example.com",
        password: "password123",
        password_confirmation: "password123",
        plan: "free"
      )
    end

    let(:optimization_result) do
      { "sheets" => [], "efficiency" => 85.0, "total_sheets" => 1 }
    end

    before do
      sign_in user
      allow(RustCuttingService).to receive(:optimize).and_return(optimization_result)
    end

    it "allows creating a project with 25 pieces or fewer" do
      post projects_path, params: {
        name: "Small Project", stock_l: 2440, stock_w: 1220,
        pieces: [ { length: 500, width: 300, quantity: 25 } ]
      }

      expect(response).to redirect_to(project_path(Project.last.token))
    end

    it "denies creating a project with more than 25 pieces and redirects to plans" do
      post projects_path, params: {
        name: "Large Project", stock_l: 2440, stock_w: 1220,
        pieces: [ { length: 500, width: 300, quantity: 26 } ]
      }

      expect(response).to redirect_to(plans_path)
    end

    it "denies updating a project with more than 25 pieces" do
      project = user.projects.create!(name: "My Project")
      project.optimizations.create!(status: "completed", result: optimization_result)

      patch project_path(project.token), params: {
        name: project.name, stock_l: 2440, stock_w: 1220,
        pieces: [ { length: 500, width: 300, quantity: 26 } ]
      }

      expect(response).to redirect_to(plans_path)
    end
  end

  private

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
