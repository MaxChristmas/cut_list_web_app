require "rails_helper"

RSpec.describe "Form input validation", type: :request do
  before { get root_path }

  it "sets min=1 on piece length inputs" do
    expect(response.body).to include('name="pieces[][length]" min="1"')
  end

  it "sets min=1 on piece width inputs" do
    expect(response.body).to include('name="pieces[][width]" min="1"')
  end

  it "sets min=1 on piece quantity inputs" do
    expect(response.body).to include('name="pieces[][quantity]" min="1"')
  end

  it "sets min=1 on stock length input" do
    expect(response.body).to include('name="stock_l" min="1"')
  end

  it "sets min=1 on stock width input" do
    expect(response.body).to include('name="stock_w" min="1"')
  end
end
