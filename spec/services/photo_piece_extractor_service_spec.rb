require "rails_helper"

RSpec.describe PhotoPieceExtractorService do
  # ──────────────────────────────────────────────
  # Helpers & shared doubles
  # ──────────────────────────────────────────────

  # Real 1×1 PNG from fixtures — tiny enough to skip compression
  let(:small_png_data) do
    File.binread(Rails.root.join("spec/fixtures/files/test_photo.png"))
  end

  let(:content_type) { "image/png" }

  # Build a mock response object matching Anthropic SDK shape
  def mock_response(text:, input_tokens: 50, output_tokens: 25)
    content_double = double("content", text: text)
    usage_double = double("usage", input_tokens: input_tokens, output_tokens: output_tokens)
    double("response", content: [ content_double ], usage: usage_double)
  end

  # Build mock Anthropic client, returning router_text on first call and extractor_text on second
  def stub_anthropic_client(router_text:, extractor_text:, input_tokens: 50, output_tokens: 25)
    messages_double = double("messages")
    client_double = double("Anthropic::Client", messages: messages_double)

    allow(Anthropic::Client).to receive(:new).and_return(client_double)

    call_count = 0
    allow(messages_double).to receive(:create) do
      call_count += 1
      if call_count == 1
        mock_response(text: router_text, input_tokens: input_tokens, output_tokens: output_tokens)
      else
        mock_response(text: extractor_text, input_tokens: input_tokens, output_tokens: output_tokens)
      end
    end

    { client: client_double, messages: messages_double }
  end

  let(:pieces_json) do
    '{"pieces":[{"nom":"Côté","longueur":750,"largeur":500,"quantite":2,"materiau":null,"confiance":"haute"}]}'
  end

  # ──────────────────────────────────────────────
  # #call — full integration (mocked Anthropic)
  # ──────────────────────────────────────────────

  describe "#call" do
    it "returns a hash with pieces, image_type, token counts and cost" do
      stub_anthropic_client(router_text: "plan_2d", extractor_text: pieces_json)

      result = described_class.new(small_png_data, content_type).call

      expect(result).to include("pieces", "image_type", "input_tokens", "output_tokens", "cost_usd")
    end

    it "returns the image_type identified by the router for plan_2d" do
      stub_anthropic_client(router_text: "plan_2d", extractor_text: pieces_json)

      result = described_class.new(small_png_data, content_type).call

      expect(result["image_type"]).to eq("plan_2d")
    end

    it "returns the image_type identified by the router for liste" do
      stub_anthropic_client(router_text: "liste", extractor_text: pieces_json)

      result = described_class.new(small_png_data, content_type).call

      expect(result["image_type"]).to eq("liste")
    end

    it "sums tokens across both API calls" do
      messages_double = double("messages")
      client_double = double("Anthropic::Client", messages: messages_double)
      allow(Anthropic::Client).to receive(:new).and_return(client_double)

      call_count = 0
      allow(messages_double).to receive(:create) do
        call_count += 1
        mock_response(text: call_count == 1 ? "plan_2d" : pieces_json, input_tokens: 100, output_tokens: 40)
      end

      result = described_class.new(small_png_data, content_type).call

      expect(result["input_tokens"]).to eq(200)
      expect(result["output_tokens"]).to eq(80)
    end

    it "calculates cost_usd using Sonnet 4 pricing" do
      messages_double = double("messages")
      client_double = double("Anthropic::Client", messages: messages_double)
      allow(Anthropic::Client).to receive(:new).and_return(client_double)

      call_count = 0
      allow(messages_double).to receive(:create) do
        call_count += 1
        mock_response(text: call_count == 1 ? "liste" : pieces_json, input_tokens: 1_000_000, output_tokens: 0)
      end

      result = described_class.new(small_png_data, content_type).call

      # 2M input tokens @ $3/M = $6.00
      expect(result["cost_usd"]).to be_within(0.01).of(6.0)
    end

    it "returns an empty pieces array when result has no pieces key" do
      stub_anthropic_client(router_text: "liste", extractor_text: '{"something_else":[]}')

      result = described_class.new(small_png_data, content_type).call

      expect(result["pieces"]).to eq([])
    end
  end

  # ──────────────────────────────────────────────
  # classify_image routing
  # ──────────────────────────────────────────────

  describe "image classification routing" do
    %w[plan_2d meuble_3d liste].each do |category|
      it "routes to #{category} when the router returns '#{category}'" do
        stub_anthropic_client(router_text: category, extractor_text: pieces_json)
        result = described_class.new(small_png_data, content_type).call
        expect(result["image_type"]).to eq(category)
      end
    end

    it "falls back to meuble_3d when router returns an unrecognised category" do
      # "autre" and "selfie" are not keys in AGENT_PROMPTS, so classify_image returns "meuble_3d"
      stub_anthropic_client(router_text: "autre", extractor_text: pieces_json)
      result = described_class.new(small_png_data, content_type).call
      expect(result["image_type"]).to eq("meuble_3d")
    end

    it "uses the meuble_3d prompt when router returns an unrecognised category" do
      messages_double = double("messages")
      client_double = double("Anthropic::Client", messages: messages_double)
      allow(Anthropic::Client).to receive(:new).and_return(client_double)

      call_count = 0
      allow(messages_double).to receive(:create) do |args|
        call_count += 1
        if call_count == 1
          mock_response(text: "autre") # unknown category → fallback to meuble_3d
        else
          # Verify meuble_3d prompt was used (contains "menuisier")
          content = args[:messages].first[:content]
          prompt_text = content.find { |c| c[:type] == "text" }&.fetch(:text, "")
          expect(prompt_text).to include("menuisier")
          mock_response(text: pieces_json)
        end
      end

      described_class.new(small_png_data, content_type).call
    end
  end

  # ──────────────────────────────────────────────
  # extract_pieces — JSON fallback parsing
  # ──────────────────────────────────────────────

  describe "JSON parsing in extract_pieces" do
    it "parses clean JSON without markdown" do
      stub_anthropic_client(router_text: "liste", extractor_text: pieces_json)

      result = described_class.new(small_png_data, content_type).call

      expect(result["pieces"]).to be_an(Array)
      expect(result["pieces"].first["nom"]).to eq("Côté")
    end

    it "falls back to extracting JSON when response contains surrounding text" do
      noisy = "Here are the pieces I found:\n#{pieces_json}\nLet me know if you need more."
      stub_anthropic_client(router_text: "liste", extractor_text: noisy)

      result = described_class.new(small_png_data, content_type).call

      expect(result["pieces"]).to be_an(Array)
      expect(result["pieces"].first["longueur"]).to eq(750)
    end

    it "falls back to extracting JSON when response is wrapped in markdown code block" do
      wrapped = "```json\n#{pieces_json}\n```"
      stub_anthropic_client(router_text: "liste", extractor_text: wrapped)

      result = described_class.new(small_png_data, content_type).call

      expect(result["pieces"]).to be_an(Array)
    end

    it "raises when no valid JSON can be extracted" do
      stub_anthropic_client(router_text: "liste", extractor_text: "This is not JSON at all.")

      expect {
        described_class.new(small_png_data, content_type).call
      }.to raise_error(RuntimeError, /Failed to parse Anthropic response/)
    end
  end

  # ──────────────────────────────────────────────
  # prepare_image — compression logic
  # ──────────────────────────────────────────────

  describe "prepare_image compression" do
    it "does not compress an image that is already under the base64 limit" do
      stub_anthropic_client(router_text: "liste", extractor_text: pieces_json)

      # The small PNG goes through autorot_only; ImageProcessing::Vips.source is called
      expect(ImageProcessing::Vips).to receive(:source).and_call_original.at_least(:once)

      described_class.new(small_png_data, content_type).call
    end

    it "attempts compression when image exceeds the base64 limit" do
      stub_anthropic_client(router_text: "liste", extractor_text: pieces_json)

      # Build an oversized data payload (just repeated bytes, not a real image)
      # The service will attempt to compress it via ImageProcessing::Vips
      oversized_data = ("A" * PhotoPieceExtractorService::MAX_BASE64_BYTES).b

      # We expect ImageProcessing::Vips to be invoked for the compression attempts
      pipeline = double("pipeline")
      result_file = Tempfile.new([ "compressed", ".png" ])
      result_file.binmode
      result_file.write(small_png_data)
      result_file.rewind

      allow(ImageProcessing::Vips).to receive(:source).and_return(pipeline)
      allow(pipeline).to receive(:autorot).and_return(pipeline)
      allow(pipeline).to receive(:resize_to_limit).and_return(pipeline)
      allow(pipeline).to receive(:convert).and_return(pipeline)
      allow(pipeline).to receive(:saver).and_return(pipeline)
      allow(pipeline).to receive(:call).and_return(result_file)

      result = described_class.new(oversized_data, "image/jpeg").call

      expect(result).to include("pieces")
    end
  end

  # ──────────────────────────────────────────────
  # Anthropic client initialization
  # ──────────────────────────────────────────────

  describe "client initialization" do
    it "instantiates Anthropic::Client with the API key from the environment" do
      stub_anthropic_client(router_text: "liste", extractor_text: pieces_json)

      described_class.new(small_png_data, content_type).call

      expect(Anthropic::Client).to have_received(:new).with(api_key: anything)
    end

    it "memoizes the client — only one Anthropic::Client is instantiated per service instance" do
      stub_anthropic_client(router_text: "liste", extractor_text: pieces_json)

      service = described_class.new(small_png_data, content_type)
      service.call

      expect(Anthropic::Client).to have_received(:new).once
    end
  end
end
