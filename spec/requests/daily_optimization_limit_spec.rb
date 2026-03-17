require "rails_helper"

RSpec.describe "Daily optimization limit", type: :request do
  let(:valid_params) do
    {
      name: "Test Project",
      stock_l: 2440,
      stock_w: 1220,
      pieces: [ { length: 500, width: 300, quantity: 1 } ]
    }
  end

  let(:rust_result) do
    { "sheet_count" => 1, "waste_percent" => 10.0, "sheets" => [] }
  end

  def create_user(plan: "free")
    User.create!(
      email: "daily-limit-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true,
      plan: plan
    )
  end

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end

  def create_optimization(project:, created_at: Time.current)
    opt = project.optimizations.new(status: "completed", result: {}, sheets_count: 1)
    opt.created_at = created_at
    opt.save!
    opt
  end

  before do
    allow(RustCuttingService).to receive(:optimize).and_return(rust_result)
  end

  describe "free plan user" do
    let(:user) { create_user(plan: "free") }
    let(:project) { user.projects.create!(name: "Existing", sheet_length: 2440, sheet_width: 1220) }

    before { sign_in user }

    context "when under the daily limit" do
      before do
        9.times { create_optimization(project: project) }
      end

      it "allows the 10th optimization via create" do
        post projects_path, params: valid_params
        expect(response).to redirect_to(project_path(Project.last.token))
      end

      it "allows the 10th optimization via update" do
        patch project_path(project.token), params: valid_params
        expect(response).to redirect_to(project_path(project.token))
      end
    end

    context "when at the daily limit (10 optimizations today)" do
      before do
        10.times { create_optimization(project: project) }
      end

      it "blocks the 11th optimization via create and redirects to plans" do
        post projects_path, params: valid_params
        expect(response).to redirect_to(plans_path)
        expect(flash[:alert]).to eq(I18n.t("limits.max_daily_optimizations_reached"))
      end

      it "blocks the 11th optimization via update and redirects to plans" do
        patch project_path(project.token), params: valid_params
        expect(response).to redirect_to(plans_path)
        expect(flash[:alert]).to eq(I18n.t("limits.max_daily_optimizations_reached"))
      end

      it "does not call RustCuttingService when blocked" do
        post projects_path, params: valid_params
        expect(RustCuttingService).not_to have_received(:optimize)
      end
    end

    context "when daily counter resets the next day" do
      before do
        10.times { create_optimization(project: project, created_at: 1.day.ago) }
      end

      it "allows optimization today after yesterday's 10" do
        post projects_path, params: valid_params
        expect(response).to redirect_to(project_path(Project.last.token))
      end
    end

    context "when limit is spread across multiple projects" do
      let(:project2) { user.projects.create!(name: "Second", sheet_length: 2440, sheet_width: 1220) }

      before do
        5.times { create_optimization(project: project) }
        5.times { create_optimization(project: project2) }
      end

      it "counts optimizations from all projects toward the daily limit" do
        post projects_path, params: valid_params
        expect(response).to redirect_to(plans_path)
      end
    end
  end

  describe "worker plan user" do
    let(:user) { create_user(plan: "worker") }
    let(:project) { user.projects.create!(name: "Worker Project", sheet_length: 2440, sheet_width: 1220) }

    before do
      sign_in user
      20.times { create_optimization(project: project) }
    end

    it "can optimize without limit via create" do
      post projects_path, params: valid_params
      expect(response).to redirect_to(project_path(Project.last.token))
    end

    it "can optimize without limit via update" do
      patch project_path(project.token), params: valid_params
      expect(response).to redirect_to(project_path(project.token))
    end
  end
end
