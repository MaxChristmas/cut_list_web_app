require "rails_helper"

RSpec.describe "Project validation", type: :request do
  let(:user) do
    User.create!(
      email: "validator@example.com",
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

  describe "POST /projects (create)" do
    it "rejects when stock dimensions are missing" do
      post projects_path, params: {
        name: "Test", stock_l: "", stock_w: "",
        pieces: [ { length: 500, width: 300, quantity: 1 } ]
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects when no pieces are provided" do
      post projects_path, params: {
        name: "Test", stock_l: 2440, stock_w: 1220,
        pieces: []
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects when pieces have blank dimensions" do
      post projects_path, params: {
        name: "Test", stock_l: 2440, stock_w: 1220,
        pieces: [ { length: "", width: "", quantity: 1 } ]
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects when stock length < stock width" do
      post projects_path, params: {
        name: "Test", stock_l: 1000, stock_w: 2000,
        pieces: [ { length: 500, width: 300, quantity: 1 } ]
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects when a piece length < piece width" do
      post projects_path, params: {
        name: "Test", stock_l: 2440, stock_w: 1220,
        pieces: [ { length: 300, width: 500, quantity: 1 } ]
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "accepts when stock length == stock width" do
      post projects_path, params: {
        name: "Test", stock_l: 1000, stock_w: 1000,
        pieces: [ { length: 500, width: 300, quantity: 1 } ]
      }

      expect(response).to redirect_to(project_path(Project.last.token))
    end

    it "accepts when piece length == piece width" do
      post projects_path, params: {
        name: "Test", stock_l: 2440, stock_w: 1220,
        pieces: [ { length: 500, width: 500, quantity: 1 } ]
      }

      expect(response).to redirect_to(project_path(Project.last.token))
    end

    it "accepts valid params" do
      post projects_path, params: {
        name: "Test", stock_l: 2440, stock_w: 1220,
        pieces: [ { length: 500, width: 300, quantity: 1 } ]
      }

      expect(response).to redirect_to(project_path(Project.last.token))
    end
  end

  describe "PATCH /projects/:token (update)" do
    let(:project) do
      user.projects.create!(name: "Existing", sheet_length: 2440, sheet_width: 1220)
    end

    before do
      project.optimizations.create!(status: "completed", result: optimization_result)
    end

    it "rejects when stock dimensions are missing" do
      patch project_path(project.token), params: {
        name: "Test", stock_l: "", stock_w: "",
        pieces: [ { length: 500, width: 300, quantity: 1 } ]
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects when no pieces are provided" do
      patch project_path(project.token), params: {
        name: "Test", stock_l: 2440, stock_w: 1220,
        pieces: []
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects when stock length < stock width" do
      patch project_path(project.token), params: {
        name: "Test", stock_l: 1000, stock_w: 2000,
        pieces: [ { length: 500, width: 300, quantity: 1 } ]
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects when a piece length < piece width" do
      patch project_path(project.token), params: {
        name: "Test", stock_l: 2440, stock_w: 1220,
        pieces: [ { length: 300, width: 500, quantity: 1 } ]
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "accepts valid params" do
      patch project_path(project.token), params: {
        name: "Updated", stock_l: 2440, stock_w: 1220,
        pieces: [ { length: 500, width: 300, quantity: 1 } ]
      }

      expect(response).to redirect_to(project_path(project.token))
    end
  end

  private

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
