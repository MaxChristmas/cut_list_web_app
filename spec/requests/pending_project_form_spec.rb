require "rails_helper"

# Regression protection: the pending-project Stimulus controller and its data values
# must be present on the root form so the JS can save/restore form data across
# redirects (limit hits, checkout flow, etc.).
RSpec.describe "Pending project form attributes", type: :request do
  before { get root_path }

  it "mounts the pending-project Stimulus controller on the form" do
    expect(response.body).to include('data-controller="pending-project"')
  end

  it "includes the create URL value for the pending-project controller" do
    expect(response.body).to include("pending-project-create-url-value")
    expect(response.body).to include(projects_path)
  end

  it "includes the checkout URL value for the pending-project controller" do
    expect(response.body).to include("pending-project-checkout-url-value")
    expect(response.body).to include(plan_checkout_path)
  end

  it "renders the form with the correct action (projects POST)" do
    expect(response.body).to include("action=\"#{projects_path}\"")
  end
end
