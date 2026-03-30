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

    it "includes HEADER section with AC1015 version and mm units" do
      expect(dxf).to include("$ACADVER\n1\nAC1015")
      expect(dxf).to include("$INSUNITS\n70\n4")
    end

    it "includes all required DXF sections" do
      expect(dxf).to include("0\nSECTION\n2\nHEADER")
      expect(dxf).to include("0\nSECTION\n2\nTABLES")
      expect(dxf).to include("0\nSECTION\n2\nENTITIES")
      expect(dxf).to include("0\nENDSEC")
      expect(dxf).to include("0\nEOF")
    end

    it "includes LTYPE table with CONTINUOUS line type" do
      expect(dxf).to include("TABLE\n2\nLTYPE")
      expect(dxf).to include("CONTINUOUS")
    end

    # ── Layers ─────────────────────────────────────────────────────

    it "includes mandatory layer 0" do
      expect(dxf).to include("LAYER\n2\n0\n70\n0\n62\n7")
    end

    it "defines a layer for each sheet" do
      expect(dxf).to include("SHEET_1")
      expect(dxf).to include("SHEET_2")
    end

    it "does not define layers beyond sheet count" do
      expect(dxf).not_to include("SHEET_3")
    end

    it "assigns distinct colors to each sheet layer" do
      # SHEET_1 color 1, SHEET_2 color 2
      expect(dxf).to include("LAYER\n2\nSHEET_1\n70\n0\n62\n1")
      expect(dxf).to include("LAYER\n2\nSHEET_2\n70\n0\n62\n2")
    end

    # ── Stock outlines ─────────────────────────────────────────────

    it "draws one stock outline per sheet as gray LWPOLYLINE" do
      # color 8 = gray for stock outlines
      stock_outlines = dxf.scan(/LWPOLYLINE\n8\nSHEET_\d+\n62\n8/).size
      expect(stock_outlines).to eq(2)
    end

    it "draws stock rectangle with correct dimensions" do
      # Stock 1200x600, bottom-left origin: corners at (0,0) and (1200,600)
      expect(dxf).to include("10\n1200.0\n20\n0.0")
      expect(dxf).to include("10\n1200.0\n20\n600.0")
    end

    # ── Piece placements ───────────────────────────────────────────

    it "draws one LWPOLYLINE per piece placement" do
      # 3 pieces + 2 stock outlines = 5 total
      polyline_count = dxf.scan("LWPOLYLINE").size
      expect(polyline_count).to eq(5)
    end

    it "places piece rectangles on the correct sheet layer" do
      sheet1_pieces = dxf.scan(/LWPOLYLINE\n8\nSHEET_1\n62\n1/).size
      expect(sheet1_pieces).to eq(3)
    end

    it "flips y-coordinates from top-left to DXF bottom-left origin" do
      # Piece at (0,0) with size 400x200, stock height 600
      # DXF y = 600 - 0 - 200 = 400, so bottom-left at (0, 400), top-left at (0, 600)
      expect(dxf).to include("10\n0.0\n20\n400.0")
    end

    # ── Labels ─────────────────────────────────────────────────────

    it "adds TEXT entities only for pieces with labels" do
      text_count = dxf.scan(/^TEXT$/).size
      # Only the 2 placements matching "Shelf" (400x200) get labels
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
      # First Shelf piece: x=0, w=400 → cx=200; y=0, h=200 → cy=100
      # DXF cy = 600 - 100 = 500
      expect(dxf).to include("10\n200.0\n20\n500.0")
    end

    it "does not add labels for pieces without a label defined" do
      # Extract the content line (group code 1) from each TEXT entity
      labels = dxf.scan(/\n0\nTEXT\n(?:.*\n)*?1\n(.+)\n/).flatten
      expect(labels).to eq([ "Shelf", "Shelf" ])
    end

    # ── Edge cases ─────────────────────────────────────────────────

    context "when there are no sheets" do
      let(:result) { { "stock" => { "w" => 1000, "h" => 500 }, "sheets" => [] } }

      it "produces valid DXF with no entities" do
        expect(dxf).to include("0\nSECTION\n2\nENTITIES\n0\nENDSEC")
        expect(dxf).to include("0\nEOF")
      end

      it "still includes mandatory layer 0" do
        expect(dxf).to include("LAYER\n2\n0\n70")
      end
    end

    context "when a sheet has no placements" do
      it "draws only the stock outline for that sheet" do
        # Sheet 2 has no placements, so only 1 LWPOLYLINE on SHEET_2 (the stock)
        sheet2_polylines = dxf.scan(/LWPOLYLINE\n8\nSHEET_2/).size
        expect(sheet2_polylines).to eq(1)
      end
    end

    context "when no pieces have labels" do
      let(:result) do
        {
          "stock" => { "w" => 500, "h" => 300 },
          "pieces" => [
            { "length" => 200, "width" => 100, "quantity" => 1 }
          ],
          "sheets" => [
            {
              "waste_area" => 0,
              "placements" => [
                { "rect" => { "w" => 200, "h" => 100 }, "x" => 0, "y" => 0 }
              ]
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
          "pieces" => [
            { "l" => 200, "w" => 100, "quantity" => 1, "label" => "Side" }
          ],
          "sheets" => [
            {
              "waste_area" => 0,
              "placements" => [
                { "rect" => { "length" => 200, "width" => 100 }, "x" => 0, "y" => 0 }
              ]
            }
          ]
        }
      end

      it "handles alternative stock key names" do
        expect(dxf).to include("10\n800.0\n20\n400.0")
      end

      it "handles alternative rect key names" do
        expect(dxf).to include("LWPOLYLINE")
        expect { dxf }.not_to raise_error
      end

      it "handles alternative piece key names for labels" do
        expect(dxf).to include("Side")
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
              "placements" => [
                { "rect" => { "w" => 333.3, "h" => 166.7 }, "x" => 0, "y" => 0 }
              ]
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
