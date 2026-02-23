require "rails_helper"

RSpec.describe "Optimization rate limiting", type: :request do
  let(:user) do
    User.create!(
      email: "ratelimit@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true,
      plan: "enterprise"
    )
  end

  let(:project) { user.projects.create!(name: "Rate Limit Project") }

  let(:optimization_result) do
    { "sheets" => [], "efficiency" => 85.0, "total_sheets" => 1 }
  end

  let(:update_params) do
    {
      name: "Test", stock_l: 2440, stock_w: 1220,
      pieces: [{ length: 500, width: 300, quantity: 1 }]
    }
  end

  before do
    sign_in user
    allow(RustCuttingService).to receive(:optimize).and_return(optimization_result)
  end

  it "allows up to 3 optimization requests per second" do
    3.times do
      patch project_path(project.token), params: update_params
      expect(response).to have_http_status(:redirect)
    end
  end

  it "rejects the 4th optimization request within one second" do
    3.times { patch project_path(project.token), params: update_params }

    patch project_path(project.token), params: update_params
    expect(response).to have_http_status(:too_many_requests)
  end

  private

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
