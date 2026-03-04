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

# --- Users ---
users = []

user_data = [
  { email: "alice@example.com", plan: "free", created_at: 45.days.ago },
  { email: "bob@example.com", plan: "worker", plan_expires_at: 25.days.from_now, created_at: 30.days.ago },
  { email: "charlie@example.com", plan: "enterprise", plan_expires_at: 180.days.from_now, created_at: 60.days.ago },
  { email: "diana@example.com", plan: "worker", plan_expires_at: 10.days.ago, created_at: 90.days.ago }
]

user_data.each do |data|
  user = User.find_or_create_by!(email: data[:email]) do |u|
    u.password = "password123"
    u.plan = data[:plan]
    u.plan_expires_at = data[:plan_expires_at]
    u.terms_accepted = true
    u.created_at = data[:created_at]
  end
  users << user
end

# --- Coupons ---
Coupon.find_or_create_by!(code: "WORKER") do |c|
  c.plan = "worker"
  c.duration_days = 30
  c.max_uses = 50
  c.expires_at = 60.days.from_now
end

Coupon.find_or_create_by!(code: "ENTPRO") do |c|
  c.plan = "enterprise"
  c.duration_days = 90
  c.max_uses = 10
  c.expires_at = 30.days.from_now
end

# --- Projects ---
project_names = [
  "Kitchen Shelves", "Bedroom Wardrobe", "Office Desk", "Bathroom Cabinet",
  "Garage Storage", "Bookshelf", "TV Stand", "Shoe Rack",
  "Dining Table", "Coffee Table", "Pantry Organizer", "Workbench",
  "Floating Shelves", "Toy Box", "Wine Rack", "Garden Planter Box",
  "Spice Rack", "Night Stand", "Laundry Cabinet", "Tool Chest",
  "Display Case", "Hall Console", "Craft Table", "Pet House"
]

sheet_configs = [
  { sheet_length: 2500, sheet_width: 600, grain_direction: "along_length" },
  { sheet_length: 2440, sheet_width: 1220, grain_direction: "none" },
  { sheet_length: 3000, sheet_width: 600, grain_direction: "along_width" },
  { sheet_length: 1800, sheet_width: 400, grain_direction: "none" },
  { sheet_length: 2500, sheet_width: 1250, grain_direction: "along_length" }
]

piece_templates = [
  [
    { label: "Side", width: 300, length: 800, quantity: 2 },
    { label: "Shelf", width: 250, length: 600, quantity: 4 },
    { label: "Back", width: 600, length: 800, quantity: 1 },
    { label: "Top", width: 300, length: 600, quantity: 1 }
  ],
  [
    { label: "Panel", width: 400, length: 1200, quantity: 2 },
    { label: "Door", width: 500, length: 700, quantity: 2 },
    { label: "Shelf", width: 380, length: 550, quantity: 6 },
    { label: "Base", width: 400, length: 600, quantity: 1 }
  ],
  [
    { label: "Top", width: 600, length: 1400, quantity: 1 },
    { label: "Leg", width: 80, length: 720, quantity: 4 },
    { label: "Rail", width: 100, length: 1200, quantity: 2 },
    { label: "Stretcher", width: 80, length: 500, quantity: 2 }
  ],
  [
    { label: "Plank", width: 200, length: 900, quantity: 8 },
    { label: "Support", width: 100, length: 400, quantity: 4 },
    { label: "Brace", width: 50, length: 200, quantity: 6 }
  ]
]

project_index = 0
users.each_with_index do |user, user_idx|
  # Each user gets 5-7 projects
  count = [5, 6, 7, 6][user_idx]
  count.times do
    name = project_names[project_index % project_names.size]
    config = sheet_configs[project_index % sheet_configs.size]
    pieces = piece_templates[project_index % piece_templates.size]
    created = rand(1..60).days.ago

    project = Project.find_or_create_by!(name: name, user: user) do |p|
      p.sheet_length = config[:sheet_length]
      p.sheet_width = config[:sheet_width]
      p.grain_direction = config[:grain_direction]
      p.created_at = created
      p.archived_at = (project_index % 7 == 0) ? 5.days.ago : nil
    end

    # Add an optimization with a basic result
    if project.optimizations.empty?
      sheets_count = rand(1..6)
      efficiency = rand(55.0..92.0).round(2)

      placements = pieces.flat_map do |piece|
        piece[:quantity].times.map do |i|
          {
            "x" => rand(0..500),
            "y" => rand(0..300),
            "rect" => { "width" => piece[:width], "length" => piece[:length] },
            "rotated" => [true, false].sample
          }
        end
      end

      result = {
        "kerf" => "3",
        "stock" => { "width" => config[:sheet_width], "length" => config[:sheet_length] },
        "pieces" => pieces.map { |p| p.transform_keys(&:to_s) },
        "sheets" => sheets_count.times.map do
          { "placements" => placements.sample(rand(3..8)), "waste_area" => rand(100_000..500_000) }
        end,
        "sheet_count" => sheets_count,
        "waste_percent" => (100.0 - efficiency).round(2)
      }

      project.optimizations.create!(
        result: result,
        status: "completed",
        sheets_count: sheets_count,
        efficiency: efficiency,
        cut_direction: %w[auto along_length along_width].sample,
        created_at: created + rand(1..120).minutes
      )
    end

    project_index += 1
  end
end

puts "Seeded #{User.count} users, #{Project.count} projects, #{Optimization.count} optimizations, #{Coupon.count} coupons"

# Template project — visible to unauthenticated users as an example
template_project = Project.find_or_create_by!(template: true) do |project|
  project.name = "Example Cut List"
  project.sheet_length = 2500
  project.sheet_width = 600
  project.grain_direction = "along_length"
end

if template_project.optimizations.empty?
  template_result = {
    "kerf" => "3",
    "stock" => { "width" => 600, "length" => 2500 },
    "pieces" => [
      { "label" => "DDH", "width" => "188", "length" => "648", "quantity" => "4", "grain" => "length" },
      { "label" => "EQP", "width" => "188", "length" => "473", "quantity" => "4" },
      { "label" => "RRR", "width" => "244", "length" => "790", "quantity" => "2", "grain" => "length" },
      { "label" => "SWO", "width" => "150", "length" => "648", "quantity" => "12" },
      { "label" => "QAQ", "width" => "150", "length" => "473", "quantity" => "12" },
      { "label" => "XYC", "width" => "170", "length" => "790", "quantity" => "4", "grain" => "width" },
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
