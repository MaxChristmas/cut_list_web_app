require "rails_helper"

RSpec.describe CutListDxfService do
  let(:result) do
    {
      "stock" => { "w" => 1200, "h" => 600 },
      "kerf" => 3,
      "pieces" => [
        { "length" => 400, "width" => 200, "quantity" => 2, "label" => "Shelf" },
        { "length" => 300, "width" => 150, "quantity" => 1 }
      ],
      "sheets" => [
        {
          "waste_area" => 100_000,
          "placements" => [
            { "rect" => { "w" => 400, "h" => 200 }, "x" => 0,   "y" => 0   },
            { "rect" => { "w" => 400, "h" => 200 }, "x" => 400, "y" => 0   },
            { "rect" => { "w" => 300, "h" => 150 }, "x" => 0,   "y" => 200 }
          ]
        },
        {
          "waste_area" => 720_000,
          "placements" => []
        }
      ]
    }
  end

  let(:project) { instance_double("Project", name: "My Project", token: "abc123") }

  subject(:service) { described_class.new(result, project) }

  describe "#generate" do
    subject(:dxf) { service.generate }

    # ── DXF structure ──────────────────────────────────────────────

    it "returns a non-empty string" do
      expect(dxf).to be_a(String)
      expect(dxf).not_to be_empty
    end

    it "has minimal structure: ENTITIES section + EOF only" do
      expect(dxf).to start_with("0\nSECTION\n2\nENTITIES\n")
      expect(dxf).to end_with("0\nENDSEC\n0\nEOF\n")
      expect(dxf).not_to include("SECTION\n2\nHEADER")
      expect(dxf).not_to include("LWPOLYLINE")
    end

    # ── Layers ─────────────────────────────────────────────────────

    it "references a layer for each sheet" do
      expect(dxf).to include("8\nSHEET_1\n")
      expect(dxf).to include("8\nSHEET_2\n")
    end

    it "does not reference layers beyond sheet count" do
      expect(dxf).not_to include("SHEET_3")
    end

    it "assigns distinct colors to sheet piece entities" do
      # SHEET_1 has placements → piece lines with color 1
      expect(dxf).to include("8\nSHEET_1\n62\n1\n")
      # SHEET_2 has no placements → no piece lines, only stock outline (color 8)
      expect(dxf).not_to include("8\nSHEET_2\n62\n2\n")
    end

    # ── Stock outlines ─────────────────────────────────────────────

    it "draws 4 LINE entities per stock outline (one per side), gray color" do
      # color 8 = gray; 4 sides × 2 sheets = 8 LINE entities
      stock_lines = dxf.scan(/8\nSHEET_\d+\n62\n8\n/).size
      expect(stock_lines).to eq(8)
    end

    it "draws stock rectangle with correct dimensions" do
      # Stock 1200×600: right edge goes from (1200,0) to (1200,600)
      expect(dxf).to include("10\n1200.0\n20\n0.0")
      expect(dxf).to include("10\n1200.0\n20\n600.0")
    end

    # ── Piece placements ───────────────────────────────────────────

    it "draws 4 LINE entities per piece placement" do
      # (3 placements + 2 stock outlines) × 4 sides = 20 LINE entities
      expect(dxf.scan(/\n0\nLINE\n/).size).to eq(20)
    end

    it "places piece rectangles on the correct sheet layer" do
      # 3 pieces × 4 sides = 12 LINE entities on SHEET_1 with color 1
      sheet1_piece_lines = dxf.scan(/8\nSHEET_1\n62\n1\n/).size
      expect(sheet1_piece_lines).to eq(12)
    end

    it "flips y-coordinates from top-left to DXF bottom-left origin" do
      # Piece at (0,0) size 400×200, stock height 600 → DXF y = 600-0-200 = 400
      expect(dxf).to include("10\n0.0\n20\n400.0")
    end

    it "includes Z coordinate 0.0 on all LINE endpoints" do
      expect(dxf).to include("30\n0.0")
      expect(dxf).to include("31\n0.0")
    end

    # ── Labels ─────────────────────────────────────────────────────

    it "adds TEXT entities only for pieces with labels" do
      text_count = dxf.scan(/^TEXT$/).size
      # Only the 2 placements matching "Shelf" (400×200) get labels
      expect(text_count).to eq(2)
    end

    it "includes the piece label text" do
      expect(dxf).to include("Shelf")
    end

    it "does not include dimension text" do
      expect(dxf).not_to include("400x200")
      expect(dxf).not_to include("300x150")
    end

    it "centers label text in the piece" do
      # First Shelf: x=0, w=400 → cx=200; y=0, h=200 → cy=100; DXF cy=600-100=500
      expect(dxf).to include("10\n200.0\n20\n500.0")
    end

    it "does not add labels for pieces without a label defined" do
      labels = dxf.scan(/\n0\nTEXT\n(?:.*\n)*?1\n(.+)\n/).flatten
      expect(labels).to eq([ "Shelf", "Shelf" ])
    end

    # ── Edge cases ─────────────────────────────────────────────────

    context "when there are no sheets" do
      let(:result) { { "stock" => { "w" => 1000, "h" => 500 }, "sheets" => [] } }

      it "produces valid DXF with no entities" do
        expect(dxf).to include("0\nSECTION\n2\nENTITIES\n0\nENDSEC")
        expect(dxf).to end_with("0\nEOF\n")
      end
    end

    context "when a sheet has no placements" do
      it "draws only the stock outline for that sheet (4 LINE entities)" do
        sheet2_lines = dxf.scan(/8\nSHEET_2\n/).size
        expect(sheet2_lines).to eq(4)
      end
    end

    context "when no pieces have labels" do
      let(:result) do
        {
          "stock" => { "w" => 500, "h" => 300 },
          "pieces" => [ { "length" => 200, "width" => 100, "quantity" => 1 } ],
          "sheets" => [
            {
              "waste_area" => 0,
              "placements" => [ { "rect" => { "w" => 200, "h" => 100 }, "x" => 0, "y" => 0 } ]
            }
          ]
        }
      end

      it "generates no TEXT entities" do
        expect(dxf).not_to include("\n0\nTEXT\n")
      end
    end

    context "when result uses alternative key names (length/width)" do
      let(:result) do
        {
          "stock" => { "length" => 800, "width" => 400 },
          "pieces" => [ { "l" => 200, "w" => 100, "quantity" => 1, "label" => "Side" } ],
          "sheets" => [
            {
              "waste_area" => 0,
              "placements" => [ { "rect" => { "length" => 200, "width" => 100 }, "x" => 0, "y" => 0 } ]
            }
          ]
        }
      end

      it "handles alternative stock key names" do
        expect(dxf).to include("10\n800.0\n20\n400.0")
      end

      it "handles alternative rect key names" do
        expect(dxf).to include("LINE")
        expect { dxf }.not_to raise_error
      end

      it "handles alternative piece key names for labels" do
        expect(dxf).to include("Side")
      end
    end

    context "with margin" do
      let(:result) do
        {
          "stock" => { "w" => 1180, "h" => 580 },
          "margin" => 10,
          "pieces" => [],
          "sheets" => [
            {
              "waste_area" => 0,
              "placements" => [
                { "rect" => { "w" => 400, "h" => 200 }, "x" => 0, "y" => 0 }
              ]
            }
          ]
        }
      end

      it "uses full sheet dimensions (effective + 2×margin) for the stock outline" do
        # effective 1180+2×10=1200 wide, 580+2×10=600 tall
        expect(dxf).to include("10\n1200.0")
        expect(dxf).to include("20\n600.0")
      end

      it "offsets piece placements by margin in X and Y" do
        # Piece at x=0, y=0 in effective space → rendered at px=10, py=10
        # DXF y-flip: sh(600) - py(10) - ph(200) = 390
        expect(dxf).to include("10\n10.0\n20\n390.0")
      end
    end

    context "with decimal dimensions" do
      let(:result) do
        {
          "stock" => { "w" => 1000.5, "h" => 500.25 },
          "pieces" => [],
          "sheets" => [
            {
              "waste_area" => 0,
              "placements" => [ { "rect" => { "w" => 333.3, "h" => 166.7 }, "x" => 0, "y" => 0 } ]
            }
          ]
        }
      end

      it "preserves decimal precision in coordinates" do
        expect(dxf).to include("1000.5")
        expect(dxf).to include("500.25")
      end
    end
  end
end
