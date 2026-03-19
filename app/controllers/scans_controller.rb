class ScansController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :upload
  layout "scan"

  def show
    @scan_token = ScanToken.find_by(token: params[:token])

    if @scan_token.nil? || !@scan_token.usable?
      @error = true
    end
  end

  def upload
    scan_token = ScanToken.find_by(token: params[:token])

    if scan_token.nil? || !scan_token.usable?
      @upload_error = t("scan.expired_title")
      render :upload_error
      return
    end

    photo = params[:photo]
    unless photo.is_a?(ActionDispatch::Http::UploadedFile)
      @upload_error = t("scan.no_photo")
      render :upload_error
      return
    end

    unless photo.content_type.start_with?("image/")
      @upload_error = t("scan.invalid_file_type")
      render :upload_error
      return
    end

    if photo.size > 10.megabytes
      @upload_error = t("scan.file_too_large")
      render :upload_error
      return
    end

    scan_token.mark_processing!

    # Immediately broadcast "analyzing" state to desktop — greys out QR code
    locale = scan_token.user&.locale&.to_sym || I18n.default_locale
    I18n.with_locale(locale) do
      Turbo::StreamsChannel.broadcast_replace_to(
        "scan_token_#{scan_token.id}",
        target: "scan_photo_preview",
        partial: "scan_tokens/analyzing",
        locals: { scan_token: scan_token }
      )

      Turbo::StreamsChannel.broadcast_replace_to(
        "scan_token_#{scan_token.id}",
        target: "photo_import_result",
        partial: "scan_tokens/analyzing_status",
        locals: {}
      )
    end

    begin
      image_data = photo.read

      # Apply EXIF rotation before storing so the image displays correctly everywhere
      rotated_data = autorot_image(image_data, photo.content_type)
      scan_token.photo.attach(
        io: StringIO.new(rotated_data),
        filename: photo.original_filename.sub(/\.\w+$/, ".jpg"),
        content_type: "image/jpeg"
      )

      # Classify the image first with the chosen provider
      service_class = scan_token.ai_provider == "openai" ? PhotoPieceExtractorOpenaiService : PhotoPieceExtractorService
      service = service_class.new(image_data, photo.content_type)
      result = service.call

      # Force the best provider per image type:
      # - liste → OpenAI (GPT-4o reads tables better)
      # - plan_2d, meuble_2d → Anthropic (better at technical drawings)
      # - meuble_3d → user's choice
      image_type = result["image_type"]
      if image_type == "liste" && service_class != PhotoPieceExtractorOpenaiService
        Rails.logger.info("[PhotoImport] Forcing OpenAI for liste extraction")
        result = PhotoPieceExtractorOpenaiService.new(image_data, photo.content_type).call
      elsif image_type.in?(%w[plan_2d meuble_2d meuble_3d]) && service_class != PhotoPieceExtractorService
        Rails.logger.info("[PhotoImport] Forcing Anthropic for #{image_type} extraction")
        result = PhotoPieceExtractorService.new(image_data, photo.content_type).call
      end
      pieces = normalize_pieces(result["pieces"] || [])
      pieces = merge_duplicate_pieces(pieces)

      scan_token.mark_completed!(pieces)
      scan_token.update!(
        image_type: result["image_type"],
        input_tokens: result["input_tokens"],
        output_tokens: result["output_tokens"],
        cost_usd: result["cost_usd"]
      )

      # Use the scan token owner's locale for broadcasting
      locale = scan_token.user&.locale&.to_sym || I18n.default_locale

      I18n.with_locale(locale) do
        # Broadcast photo preview + pieces to desktop via Turbo Stream
        Turbo::StreamsChannel.broadcast_replace_to(
          "scan_token_#{scan_token.id}",
          target: "scan_photo_preview",
          partial: "scan_tokens/photo_preview",
          locals: { scan_token: scan_token }
        )

        Turbo::StreamsChannel.broadcast_replace_to(
          "scan_token_#{scan_token.id}",
          target: "photo_import_result",
          partial: "scan_tokens/pieces_review",
          locals: { pieces: pieces, scan_token: scan_token }
        )
      end

      render :upload_success
    rescue => e
      scan_token.update!(status: "pending")
      Rails.logger.error("[PhotoImport] #{e.class}: #{e.message}")

      # Broadcast error to desktop
      I18n.with_locale(locale) do
        Turbo::StreamsChannel.broadcast_replace_to(
          "scan_token_#{scan_token.id}",
          target: "scan_photo_preview",
          partial: "scan_tokens/error",
          locals: { message: t("scan.analysis_failed"), scan_token: scan_token }
        )

        Turbo::StreamsChannel.broadcast_replace_to(
          "scan_token_#{scan_token.id}",
          target: "photo_import_result",
          html: '<div id="photo_import_result"></div>'
        )
      end

      @upload_error = t("scan.analysis_failed")
      render :upload_error
    end
  end

  private

  def autorot_image(image_data, content_type)
    ext = case content_type
    when "image/png" then ".png"
    when "image/webp" then ".webp"
    else ".jpg"
    end

    tempfile = Tempfile.new([ "autorot", ext ], binmode: true)
    tempfile.write(image_data)
    tempfile.rewind

    result = ImageProcessing::Vips
      .source(tempfile.path)
      .autorot
      .convert("jpeg")
      .saver(quality: 90)
      .call

    result.read
  ensure
    tempfile&.close
    tempfile&.unlink
    result&.close if result.respond_to?(:close)
  end

  def normalize_pieces(pieces)
    pieces.map do |p|
      l = p["longueur"].to_f.ceil
      w = p["largeur"].to_f.ceil
      # Ensure longueur >= largeur
      if w > l
        l, w = w, l
      end
      p["longueur"] = l
      p["largeur"] = w
      p
    end
  end

  def merge_duplicate_pieces(pieces)
    grouped = pieces.group_by { |p| [ p["largeur"], p["longueur"] ] }
    grouped.map do |(_w, _l), group|
      merged = group.first.dup
      merged["quantite"] = group.sum { |p| p["quantite"] || 1 }
      merged["nom"] = group.map { |p| p["nom"] }.uniq.join(", ") if group.size > 1
      merged
    end
  end
end
