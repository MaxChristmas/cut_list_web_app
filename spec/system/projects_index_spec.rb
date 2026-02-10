require "rails_helper"

RSpec.describe "Projects index – optimization layout", type: :system do
  let(:fixture_path) { Rails.root.join("spec/fixtures/files/optimization_result.json") }
  let(:optimization_result) { JSON.parse(File.read(fixture_path)) }

  before do
    allow(RustCuttingService).to receive(:optimize).and_return(optimization_result)
  end

  it "renders all sheet layouts and takes a screenshot" do
    visit root_path

    # Fill in a piece
    within("table") do
      fill_in "pieces[][length]", with: "790"
      fill_in "pieces[][height]", with: "244"
      fill_in "pieces[][quantity]", with: "2"
    end

    # Fill in stock sheet dimensions
    fill_in "stock_w", with: "2500"
    fill_in "stock_h", with: "625"

    click_button "Optimize"

    # Wait for Stimulus sheet-visualizer to render all 4 SVGs
    expect(page).to have_css("svg", minimum: 4, wait: 10)

    # Verify summary text is present
    expect(page).to have_text("4 sheet(s)")
    expect(page).to have_text("33.902208%")

    # Resize window to full page height so all sheets are captured
    full_height = page.evaluate_script("document.body.scrollHeight")
    page.driver.browser.manage.window.resize_to(1400, full_height)

    # Save screenshot
    screens_dir = Rails.root.join("spec/screens")
    FileUtils.mkdir_p(screens_dir)
    page.save_screenshot(screens_dir.join("optimization_layouts.png"))
  end
end
