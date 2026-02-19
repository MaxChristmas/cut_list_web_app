require "rails_helper"

RSpec.describe RustCuttingService do
  let(:stock) { { l: 1000, w: 500 } }
  let(:cuts) do
    [
      { l: 200, w: 100, qty: 3, grain: "length" },
      { l: 150, w: 75, qty: 2, grain: "auto" }
    ]
  end
  let(:success_body) { { "sheets" => [{ "cuts" => [] }] }.to_json }

  def stub_optimizer(status: 200, body: success_body)
    http_double = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).and_return(http_double)
    allow(http_double).to receive(:open_timeout=)
    allow(http_double).to receive(:read_timeout=)

    response = instance_double(Net::HTTPResponse, code: status.to_s, body: body)
    if status == 200
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    else
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
    end
    allow(http_double).to receive(:request) do |req|
      @captured_request = req
      response
    end

    http_double
  end

  describe ".optimize" do
    it "returns parsed JSON on success" do
      stub_optimizer
      result = described_class.optimize(stock: stock, cuts: cuts)
      expect(result).to eq("sheets" => [{ "cuts" => [] }])
    end

    it "sends correct payload structure with per-cut grain" do
      stub_optimizer
      described_class.optimize(stock: stock, cuts: cuts, kerf: 2.5, grain_direction: "along_length")

      payload = JSON.parse(@captured_request.body)
      expect(payload["stock"]).to eq("length" => 1000, "width" => 500, "grain" => "along_length")
      expect(payload["kerf"]).to eq(2.5)
      expect(payload["cuts"].length).to eq(2)
      expect(payload["cuts"][0]).to eq(
        "rect" => { "length" => 200, "width" => 100 },
        "qty" => 3,
        "grain" => "length"
      )
      expect(payload["cuts"][1]).to eq(
        "rect" => { "length" => 150, "width" => 75 },
        "qty" => 2,
        "grain" => "auto"
      )
    end

    it "sends grain direction defaulting to none" do
      stub_optimizer
      described_class.optimize(stock: stock, cuts: cuts)

      payload = JSON.parse(@captured_request.body)
      expect(payload["stock"]["grain"]).to eq("none")
    end

    it "does not send a global allow_rotate" do
      stub_optimizer
      described_class.optimize(stock: stock, cuts: cuts)

      payload = JSON.parse(@captured_request.body)
      expect(payload).not_to have_key("allow_rotate")
    end

    it "defaults kerf to 0.0" do
      stub_optimizer
      described_class.optimize(stock: stock, cuts: cuts)

      payload = JSON.parse(@captured_request.body)
      expect(payload["kerf"]).to eq(0.0)
    end

    it "raises on HTTP error" do
      stub_optimizer(status: 500, body: "Internal Server Error")
      expect {
        described_class.optimize(stock: stock, cuts: cuts)
      }.to raise_error(RuntimeError, /Optimizer returned 500/)
    end

    it "sets Content-Type to application/json" do
      stub_optimizer
      described_class.optimize(stock: stock, cuts: cuts)
      expect(@captured_request["Content-Type"]).to eq("application/json")
    end
  end
end
