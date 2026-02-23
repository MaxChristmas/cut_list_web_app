require "rails_helper"

RSpec.describe "Guest user limits", type: :request do
  describe "optimization usage for template project" do
    it "shows 0 optimizations for a template project the guest does not own" do
      template = Project.create!(name: "Example Cut Sheet", template: true)
      13.times { template.optimizations.create!(status: "completed", result: {}) }

      get project_path(template.token)

      expect(response.body).to include("0/10")
      expect(response.body).not_to include("13/10")
    end
  end

  describe "POST /projects (create)" do
    it "redirects logged-out users to root with signup prompt" do
      post projects_path, params: {
        name: "Test", stock_l: 2440, stock_w: 1220,
        pieces: [{ length: 500, width: 300, quantity: 1 }]
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
        pieces: [{ length: 500, width: 300, quantity: 1 }]
      }

      expect(response).to redirect_to(project_path(project.token))
      expect(flash[:show_signup]).to be_present
    end
  end

  describe "project and optimization limits for free plan user" do
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

    describe "project limit (max 2)" do
      it "allows creating a first project" do
        post projects_path, params: {
          name: "Project 1", stock_l: 2440, stock_w: 1220,
          pieces: [{ length: 500, width: 300, quantity: 1 }]
        }

        expect(response).to redirect_to(project_path(Project.last.token))
        expect(user.projects.count).to eq(1)
      end

      it "allows creating a second project" do
        user.projects.create!(name: "Project 1")

        post projects_path, params: {
          name: "Project 2", stock_l: 2440, stock_w: 1220,
          pieces: [{ length: 500, width: 300, quantity: 1 }]
        }

        expect(response).to redirect_to(project_path(Project.last.token))
        expect(user.projects.count).to eq(2)
      end

      it "denies creating a third project and redirects to plans" do
        2.times { |i| user.projects.create!(name: "Project #{i + 1}") }

        post projects_path, params: {
          name: "Project 3", stock_l: 2440, stock_w: 1220,
          pieces: [{ length: 500, width: 300, quantity: 1 }]
        }

        expect(response).to redirect_to(plans_path)
        expect(user.projects.count).to eq(2)
      end
    end

    describe "optimization limit (max 10 per project per month)" do
      let(:project) { user.projects.create!(name: "My Project") }

      before do
        # Create the initial optimization (free, doesn't count)
        project.optimizations.create!(status: "completed", result: optimization_result)
      end

      it "allows running optimizations up to the limit" do
        9.times { project.optimizations.create!(status: "completed", result: optimization_result) }

        patch project_path(project.token), params: {
          name: project.name, stock_l: 2440, stock_w: 1220,
          pieces: [{ length: 500, width: 300, quantity: 1 }]
        }

        expect(response).to redirect_to(project_path(project.token))
      end

      it "denies running optimization beyond the limit and redirects to plans" do
        10.times { project.optimizations.create!(status: "completed", result: optimization_result) }

        patch project_path(project.token), params: {
          name: project.name, stock_l: 2440, stock_w: 1220,
          pieces: [{ length: 500, width: 300, quantity: 1 }]
        }

        expect(response).to redirect_to(plans_path)
      end
    end
  end

  private

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
