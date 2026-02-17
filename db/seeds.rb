# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

AdminUser.find_or_create_by!(email: "maxence@noventi.fr") do |admin|
  admin.password = "maxence"
end

# Template project — visible to unauthenticated users as an example
template_project = Project.find_or_create_by!(template: true) do |project|
  project.name = "Example Cut List"
  project.sheet_length = 2500
  project.sheet_width = 600
  project.allow_rotation = true
end

if template_project.optimizations.empty?
  template_result = {
    "kerf" => "3",
    "stock" => { "width" => 600, "length" => 2500 },
    "pieces" => [
      { "label" => "DDH", "width" => "188", "length" => "648", "quantity" => "4" },
      { "label" => "EQP", "width" => "188", "length" => "473", "quantity" => "4" },
      { "label" => "RRR", "width" => "244", "length" => "790", "quantity" => "2" },
      { "label" => "SWO", "width" => "150", "length" => "648", "quantity" => "12" },
      { "label" => "QAQ", "width" => "150", "length" => "473", "quantity" => "12" },
      { "label" => "XYC", "width" => "170", "length" => "790", "quantity" => "4" },
      { "label" => "GEA", "width" => "220", "length" => "790", "quantity" => "2" }
    ],
    "sheets" => [
      {
        "placements" => [
          { "x" => 0, "y" => 0, "rect" => { "width" => 244, "length" => 790 }, "rotated" => false },
          { "x" => 793, "y" => 0, "rect" => { "width" => 244, "length" => 790 }, "rotated" => false },
          { "x" => 1586, "y" => 0, "rect" => { "width" => 220, "length" => 790 }, "rotated" => false },
          { "x" => 0, "y" => 247, "rect" => { "width" => 220, "length" => 790 }, "rotated" => false },
          { "x" => 793, "y" => 247, "rect" => { "width" => 170, "length" => 790 }, "rotated" => false },
          { "x" => 1586, "y" => 247, "rect" => { "width" => 170, "length" => 790 }, "rotated" => false }
        ],
        "waste_area" => 498280
      },
      {
        "placements" => [
          { "x" => 0, "y" => 0, "rect" => { "width" => 170, "length" => 790 }, "rotated" => false },
          { "x" => 793, "y" => 0, "rect" => { "width" => 170, "length" => 790 }, "rotated" => false },
          { "x" => 0, "y" => 173, "rect" => { "width" => 188, "length" => 648 }, "rotated" => false },
          { "x" => 651, "y" => 173, "rect" => { "width" => 188, "length" => 648 }, "rotated" => false },
          { "x" => 1302, "y" => 173, "rect" => { "width" => 188, "length" => 648 }, "rotated" => false },
          { "x" => 0, "y" => 364, "rect" => { "width" => 188, "length" => 648 }, "rotated" => false },
          { "x" => 1586, "y" => 0, "rect" => { "width" => 150, "length" => 648 }, "rotated" => false },
          { "x" => 651, "y" => 364, "rect" => { "width" => 150, "length" => 648 }, "rotated" => false },
          { "x" => 1302, "y" => 364, "rect" => { "width" => 150, "length" => 648 }, "rotated" => false },
          { "x" => 1953, "y" => 173, "rect" => { "width" => 188, "length" => 473 }, "rotated" => false },
          { "x" => 1953, "y" => 364, "rect" => { "width" => 150, "length" => 473 }, "rotated" => false }
        ],
        "waste_area" => 292630
      },
      {
        "placements" => [
          { "x" => 0, "y" => 0, "rect" => { "width" => 150, "length" => 648 }, "rotated" => false },
          { "x" => 651, "y" => 0, "rect" => { "width" => 150, "length" => 648 }, "rotated" => false },
          { "x" => 1302, "y" => 0, "rect" => { "width" => 150, "length" => 648 }, "rotated" => false },
          { "x" => 0, "y" => 153, "rect" => { "width" => 150, "length" => 648 }, "rotated" => false },
          { "x" => 651, "y" => 153, "rect" => { "width" => 150, "length" => 648 }, "rotated" => false },
          { "x" => 1302, "y" => 153, "rect" => { "width" => 150, "length" => 648 }, "rotated" => false },
          { "x" => 0, "y" => 306, "rect" => { "width" => 150, "length" => 648 }, "rotated" => false },
          { "x" => 651, "y" => 306, "rect" => { "width" => 150, "length" => 648 }, "rotated" => false },
          { "x" => 1302, "y" => 306, "rect" => { "width" => 150, "length" => 648 }, "rotated" => false },
          { "x" => 1953, "y" => 0, "rect" => { "width" => 150, "length" => 473 }, "rotated" => false },
          { "x" => 1953, "y" => 306, "rect" => { "width" => 150, "length" => 473 }, "rotated" => false },
          { "x" => 1953, "y" => 153, "rect" => { "width" => 150, "length" => 473 }, "rotated" => false }
        ],
        "waste_area" => 412350
      },
      {
        "placements" => [
          { "x" => 0, "y" => 0, "rect" => { "width" => 473, "length" => 188 }, "rotated" => true },
          { "x" => 191, "y" => 0, "rect" => { "width" => 473, "length" => 188 }, "rotated" => true },
          { "x" => 382, "y" => 0, "rect" => { "width" => 473, "length" => 188 }, "rotated" => true },
          { "x" => 573, "y" => 0, "rect" => { "width" => 473, "length" => 150 }, "rotated" => true },
          { "x" => 726, "y" => 0, "rect" => { "width" => 473, "length" => 150 }, "rotated" => true },
          { "x" => 879, "y" => 0, "rect" => { "width" => 473, "length" => 150 }, "rotated" => true },
          { "x" => 1032, "y" => 0, "rect" => { "width" => 473, "length" => 150 }, "rotated" => true },
          { "x" => 1185, "y" => 0, "rect" => { "width" => 473, "length" => 150 }, "rotated" => true },
          { "x" => 1338, "y" => 0, "rect" => { "width" => 473, "length" => 150 }, "rotated" => true },
          { "x" => 1491, "y" => 0, "rect" => { "width" => 473, "length" => 150 }, "rotated" => true },
          { "x" => 1644, "y" => 0, "rect" => { "width" => 473, "length" => 150 }, "rotated" => true }
        ],
        "waste_area" => 665628
      }
    ],
    "sheet_count" => 4,
    "waste_percent" => 31.148133333333334
  }

  template_project.optimizations.create!(
    result: template_result,
    status: "completed",
    sheets_count: 4,
    cut_direction: "auto"
  )
end
