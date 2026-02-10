require "rails_helper"

RSpec.describe "Optimization result validation" do
  let(:fixture_path) { Rails.root.join("spec/fixtures/files/optimization_result.json") }
  let(:result) { JSON.parse(File.read(fixture_path)) }
  let(:stock_w) { result["stock"]["w"] }
  let(:stock_h) { result["stock"]["h"] }

  def placement_bounds(placement)
    x = placement["x"]
    y = placement["y"]
    w = placement["rect"]["w"]
    h = placement["rect"]["h"]
    { x1: x, y1: y, x2: x + w, y2: y + h }
  end

  def overlaps?(a, b)
    a[:x1] < b[:x2] && a[:x2] > b[:x1] &&
      a[:y1] < b[:y2] && a[:y2] > b[:y1]
  end

  result_data = JSON.parse(File.read(File.join(__dir__, "../../spec/fixtures/files/optimization_result.json")))

  result_data["sheets"].each_with_index do |sheet, sheet_index|
    context "Sheet #{sheet_index + 1}" do
      let(:placements) { result["sheets"][sheet_index]["placements"] }

      it "has all pieces contained within the stock sheet (#{result_data['stock']['w']}x#{result_data['stock']['h']})" do
        placements.each_with_index do |p, i|
          bounds = placement_bounds(p)
          expect(bounds[:x1]).to be >= 0,
            "Piece #{i} (#{p['rect']['w']}x#{p['rect']['h']} at #{p['x']},#{p['y']}) extends past left edge"
          expect(bounds[:y1]).to be >= 0,
            "Piece #{i} (#{p['rect']['w']}x#{p['rect']['h']} at #{p['x']},#{p['y']}) extends past top edge"
          expect(bounds[:x2]).to be <= stock_w,
            "Piece #{i} (#{p['rect']['w']}x#{p['rect']['h']} at #{p['x']},#{p['y']}) extends past right edge: #{bounds[:x2]} > #{stock_w}"
          expect(bounds[:y2]).to be <= stock_h,
            "Piece #{i} (#{p['rect']['w']}x#{p['rect']['h']} at #{p['x']},#{p['y']}) extends past bottom edge: #{bounds[:y2]} > #{stock_h}"
        end
      end

      it "has no overlapping pieces" do
        bounds = placements.map { |p| placement_bounds(p) }

        bounds.each_with_index do |a, i|
          bounds.each_with_index do |b, j|
            next if j <= i

            expect(overlaps?(a, b)).to be(false),
              "Piece #{i} (#{placements[i]['rect']['w']}x#{placements[i]['rect']['h']} at #{placements[i]['x']},#{placements[i]['y']}) " \
              "overlaps piece #{j} (#{placements[j]['rect']['w']}x#{placements[j]['rect']['h']} at #{placements[j]['x']},#{placements[j]['y']})"
          end
        end
      end
    end
  end
end
