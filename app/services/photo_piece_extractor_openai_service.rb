class PhotoPieceExtractorOpenaiService
  # Reuse the same prompts as the Anthropic service
  JSON_FORMAT = PhotoPieceExtractorService::JSON_FORMAT
  ROUTER_PROMPT = PhotoPieceExtractorService::ROUTER_PROMPT
  AGENT_PROMPTS = PhotoPieceExtractorService::AGENT_PROMPTS
  MEUBLE_3D_PROMPT = PhotoPieceExtractorService::MEUBLE_3D_PROMPT

  MAX_IMAGE_BYTES = PhotoPieceExtractorService::MAX_IMAGE_BYTES

  # GPT-4o pricing (USD per million tokens)
  INPUT_COST_PER_M = 2.5
  OUTPUT_COST_PER_M = 10.0

  def initialize(image_data, content_type)
    @content_type = content_type
    @image_data = prepare_image(image_data)
    @base64_data = Base64.strict_encode64(@image_data)
  end

  def call
    @total_input_tokens = 0
    @total_output_tokens = 0

    # Step 1: Route to the right agent
    @image_type = classify_image

    # Step 2: Extract pieces with the specialized agent
    prompt = AGENT_PROMPTS[@image_type] || MEUBLE_3D_PROMPT
    pieces_data = extract_pieces(prompt)

    cost_usd = (@total_input_tokens * INPUT_COST_PER_M / 1_000_000.0) +
               (@total_output_tokens * OUTPUT_COST_PER_M / 1_000_000.0)

    {
      "pieces" => pieces_data["pieces"] || [],
      "image_type" => @image_type,
      "input_tokens" => @total_input_tokens,
      "output_tokens" => @total_output_tokens,
      "cost_usd" => cost_usd.round(4)
    }
  end

  private

  def classify_image
    response = client.chat(
      parameters: {
        model: "gpt-4o",
        max_tokens: 20,
        messages: [
          {
            role: "user",
            content: [
              image_payload,
              { type: "text", text: ROUTER_PROMPT }
            ]
          }
        ]
      }
    )

    track_usage(response)
    category = response.dig("choices", 0, "message", "content").strip.downcase
    Rails.logger.info("[PhotoImport:OpenAI] Image classified as: #{category}")
    AGENT_PROMPTS.key?(category) ? category : "meuble_3d"
  end

  def extract_pieces(prompt)
    response = client.chat(
      parameters: {
        model: "gpt-4o",
        max_tokens: 4096,
        messages: [
          {
            role: "user",
            content: [
              image_payload,
              { type: "text", text: prompt }
            ]
          }
        ]
      }
    )

    track_usage(response)
    text = response.dig("choices", 0, "message", "content")
    JSON.parse(text)
  rescue JSON::ParserError
    if text && (match = text.match(/\{.*\}/m))
      JSON.parse(match[0])
    else
      raise "Failed to parse OpenAI response"
    end
  end

  def image_payload
    {
      type: "image_url",
      image_url: {
        url: "data:#{@content_type};base64,#{@base64_data}",
        detail: "high"
      }
    }
  end

  # Delegate image preparation to the Anthropic service's logic
  def prepare_image(image_data)
    service = PhotoPieceExtractorService.allocate
    service.instance_variable_set(:@content_type, @content_type)
    result = service.send(:prepare_image, image_data)
    @content_type = service.instance_variable_get(:@content_type)
    result
  end

  def track_usage(response)
    usage = response["usage"] || {}
    @total_input_tokens += usage["prompt_tokens"].to_i
    @total_output_tokens += usage["completion_tokens"].to_i
  end

  def client
    @client ||= OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))
  end
end
