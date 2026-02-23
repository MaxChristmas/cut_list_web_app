require "rails_helper"

RSpec.describe "Projects index – optimization layout", type: :system do
  let(:fixture_path) { Rails.root.join("spec/fixtures/files/optimization_result.json") }
  let(:optimization_result) { JSON.parse(File.read(fixture_path)) }

  before do
    allow(RustCuttingService).to receive(:optimize).and_return(optimization_result)
  end
end
