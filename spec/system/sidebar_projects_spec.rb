require "rails_helper"

RSpec.describe "Sidebar projects visibility after sign-out", type: :system do
  include Warden::Test::Helpers

  let(:user) do
    User.create!(
      email: "sidebar-test-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true,
      plan: "free"
    )
  end

  let!(:projects) do
    3.times.map do |i|
      Project.create!(
        name: "Test Project #{i + 1}",
        sheet_length: 2400,
        sheet_width: 1200,
        user: user
      )
    end
  end

  after { Warden.test_reset! }

  it "shows user projects when signed in and hides them after sign out" do
    # Sign in and visit the app
    login_as(user, scope: :user)
    visit root_path

    # Dismiss cookie consent dialog if present
    click_button "Decline all" if page.has_button?("Decline all", wait: 2)

    # Projects should appear in the sidebar
    within("aside") do
      projects.each do |project|
        expect(page).to have_content(project.name)
      end
    end

    # Sign out and revisit
    logout(:user)
    visit root_path

    # Dismiss cookie consent dialog if present
    click_button "Decline all" if page.has_button?("Decline all", wait: 2)

    # After sign-out, user's projects should no longer appear in the sidebar
    within("aside") do
      projects.each do |project|
        expect(page).not_to have_content(project.name)
      end
    end
  end
end
