class PhotoPieceExtractorService
  # Shared JSON format instruction with concrete example
  JSON_FORMAT = <<~FORMAT.freeze
    ## FORMAT DE SORTIE

    Réponds UNIQUEMENT en JSON valide, sans markdown (pas de ```), sans commentaire, sans texte avant ou après.

    Le JSON doit avoir exactement cette structure :

    {"pieces": [{"nom": "Côté", "longueur": 750, "largeur": 500, "quantite": 2, "materiau": null, "confiance": "haute"}, {"nom": "Étagère", "longueur": 1200, "largeur": 300, "quantite": 4, "materiau": "mélaminé", "confiance": "moyenne"}]}

    Champs obligatoires pour chaque pièce :
    - nom : string, rôle du panneau
    - longueur : number, en mm, TOUJOURS >= largeur
    - largeur : number, en mm, TOUJOURS <= longueur
    - quantite : number, entier >= 1
    - materiau : string ou null
    - confiance : "haute", "moyenne" ou "basse"
  FORMAT

  # Step 1: Router — classify the image type with a cheap, fast call
  ROUTER_PROMPT = <<~PROMPT.freeze
    Classifie cette image dans UNE des catégories suivantes :

    - "plan_2d" : plan 2D technique, vue éclatée, logiciel CAO (SketchUp, Fusion 360...), rectangles cotés individuellement disposés sur une page
    - "meuble_3d" : croquis 3D, dessin en perspective, photo de meuble ou d'esquisse à main levée montrant un objet en volume
    - "liste" : tableau, liste textuelle, spreadsheet, capture d'écran avec colonnes de dimensions
    - "autre" : tout ce qui ne rentre pas dans les catégories ci-dessus

    Réponds UNIQUEMENT par le mot-clé, rien d'autre.
  PROMPT

  # Step 2a: Agent Plan 2D — rectangles cotés sur une page
  PLAN_2D_PROMPT = <<~PROMPT.freeze
    Tu es un expert en lecture de plans techniques 2D de découpe de panneaux.
    L'image montre des rectangles cotés individuellement (plan de découpe, vue éclatée, export CAO).

    ## MÉTHODE

    1. Identifie CHAQUE rectangle/forme sur l'image — ce sont les panneaux à découper
    2. Pour chaque rectangle, lis les DEUX cotes écrites (hauteur et largeur)
    3. Lis les valeurs EXACTES inscrites sur l'image — ne les arrondis PAS
    4. Attention aux virgules décimales : "54,74 cm" = 547.4 mm
    5. Si deux rectangles ont exactement les mêmes dimensions, fusionne-les en une ligne avec quantite = nombre de rectangles identiques
    6. Nomme chaque pièce par son rôle si indiqué, sinon "Panneau A", "Panneau B"...

    #{JSON_FORMAT}

    ## RÈGLES
    - Longueur >= largeur toujours
    - Convertis TOUJOURS en mm (1 cm = 10 mm, 1 pouce = 25.4 mm)
    - Lis chaque cote avec sa précision décimale complète (ex: 54,74 cm → 547.4 mm, PAS 547 mm)
    - Compte TOUS les rectangles visibles — n'en oublie aucun
    - Ignore les cotes de détail (encoches, trous, rayons) — seules les dimensions EXTÉRIEURES du rectangle comptent
  PROMPT

  # Step 2b: Agent Meuble 3D — croquis/photo de meuble à décomposer
  MEUBLE_3D_PROMPT = <<~PROMPT.freeze
    Tu es un expert menuisier. L'image montre un meuble en 3D (croquis, perspective, photo).
    Ton rôle : le décomposer en PANNEAUX PLATS individuels pour une liste de découpe.

    ## MÉTHODE

    Étape 1 — Identifier le type de meuble (étagère, armoire, caisson, bureau, commode...)
    Étape 2 — Compter CHAQUE panneau physique visible sur le dessin :
      - Côtés verticaux (généralement 2)
      - Panneaux horizontaux internes : compte les panneaux entre le dessus et le dessous.
        N lignes horizontales internes = N panneaux horizontaux internes.
      - Dessus et dessous du meuble
      - Fond/dos (généralement 1)
      - Façades/Portes/Tiroirs : si des panneaux de façade sont visibles en face avant,
        chaque façade est un panneau à découper avec ses propres dimensions (largeur × hauteur_compartiment).
      - Séparations verticales internes
    Étape 3 — Calculer les dimensions de chaque panneau :
      - Côtés : hauteur_totale × profondeur_meuble
      - Dessus/Dessous : largeur_meuble × profondeur_meuble
      - Étagères internes : largeur_meuble × profondeur_meuble
      - Façades : largeur_meuble × hauteur_compartiment
        Ex : si 4 compartiments de 20 cm → 4 façades de largeur_meuble × 200 mm
      - Fond/Dos : largeur_meuble × hauteur_totale
      - Hauteur totale = nombre de compartiments × hauteur d'un compartiment
        Ex : 4 compartiments de 20 cm → hauteur = 4 × 20 = 80 cm
      - La profondeur du meuble (cotée sur le dessus) est utilisée pour côtés, dessus/dessous, étagères.
      - La hauteur du compartiment est utilisée pour les FAÇADES (pas pour les étagères).

    #{JSON_FORMAT}

    ## RÈGLES CRITIQUES
    - UTILISE UNIQUEMENT les cotes ÉCRITES sur l'image pour les dimensions. Ne déduis JAMAIS une dimension à partir de la perspective du dessin.
    - Si une cote est écrite "50 cm", utilise 500 mm — ne l'ajuste PAS visuellement.
    - Chaque dimension d'un panneau doit provenir d'une cote écrite sur l'image. Si une dimension n'est pas cotée, déduis-la à partir des autres cotes écrites (ex: hauteur = N × espacement coté) et mets confiance "moyenne".
    - Longueur >= largeur toujours
    - Convertis en mm (1 cm = 10 mm, 1 pouce = 25.4 mm)
    - Un meuble a TOUJOURS au minimum 3-4 types de panneaux distincts
    - Ne retourne JAMAIS 1 ou 2 pièces pour un meuble entier
    - L'épaisseur du panneau n'est PAS une dimension de découpe
    - FUSIONNE les panneaux de mêmes dimensions en UNE ligne avec quantite = total
    - Si une dimension est déduite, confiance "moyenne" — si incertaine, "basse"
  PROMPT

  # Step 2c: Agent Liste — tableau ou liste de dimensions
  LISTE_PROMPT = <<~PROMPT.freeze
    L'image montre un tableau ou une liste de dimensions de pièces à découper.
    Extrais chaque ligne du tableau comme une pièce.

    #{JSON_FORMAT}

    ## RÈGLES
    - Longueur >= largeur toujours
    - Convertis en mm (1 cm = 10 mm, 1 pouce = 25.4 mm)
    - Utilise le libellé de la ligne comme nom, sinon "Pièce 1", "Pièce 2"...
    - quantite = la colonne quantité si présente, sinon 1
    - confiance "haute" si lisible, "basse" si incertaine
  PROMPT

  AGENT_PROMPTS = {
    "plan_2d" => PLAN_2D_PROMPT,
    "meuble_3d" => MEUBLE_3D_PROMPT,
    "liste" => LISTE_PROMPT
  }.freeze

  MAX_IMAGE_BYTES = 3_500_000 # 3.5 MB binary — becomes ~4.7 MB in base64 (under Anthropic's 5 MB limit)

  def initialize(image_data, content_type)
    @content_type = content_type
    @image_data = prepare_image(image_data)
    @image_payload = {
      type: "image",
      source: {
        type: "base64",
        media_type: @content_type,
        data: Base64.strict_encode64(@image_data)
      }
    }
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
    response = client.messages.create(
      model: "claude-sonnet-4-20250514",
      max_tokens: 20,
      messages: [
        {
          role: "user",
          content: [ @image_payload, { type: "text", text: ROUTER_PROMPT } ]
        }
      ]
    )

    track_usage(response)
    category = response.content.first.text.strip.downcase
    Rails.logger.info("[PhotoImport] Image classified as: #{category}")
    AGENT_PROMPTS.key?(category) ? category : "meuble_3d"
  end

  def extract_pieces(prompt)
    response = client.messages.create(
      model: "claude-sonnet-4-20250514",
      max_tokens: 4096,
      messages: [
        {
          role: "user",
          content: [ @image_payload, { type: "text", text: prompt } ]
        }
      ]
    )

    track_usage(response)
    text = response.content.first.text
    JSON.parse(text)
  rescue JSON::ParserError
    if text && (match = text.match(/\{.*\}/m))
      JSON.parse(match[0])
    else
      raise "Failed to parse Anthropic response"
    end
  end

  MAX_BASE64_BYTES = 5_242_880 # Anthropic's 5 MB base64 limit

  def prepare_image(image_data)
    original_size = image_data.bytesize
    Rails.logger.info("[PhotoImport] Original image: #{original_size} bytes, type: #{@content_type}")

    # If already under limit, just autorot and return
    base64_original = (original_size * 4.0 / 3).ceil
    if base64_original <= MAX_BASE64_BYTES
      return autorot_only(image_data)
    end

    tempfile = Tempfile.new([ "photo_import", extension_for(@content_type) ], binmode: true)
    tempfile.write(image_data)
    tempfile.rewind

    # Try PNG first (lossless — preserves text/dimensions on technical plans)
    # Then fall back to JPEG with decreasing resolution
    attempts = [
      { max_side: 2048, format: "png", quality: nil },
      { max_side: 1600, format: "png", quality: nil },
      { max_side: 2560, format: "jpeg", quality: 90 },
      { max_side: 2048, format: "jpeg", quality: 85 },
      { max_side: 1600, format: "jpeg", quality: 85 },
      { max_side: 1200, format: "jpeg", quality: 80 }
    ]

    attempts.each do |attempt|
      pipeline = ImageProcessing::Vips
        .source(tempfile.path)
        .autorot
        .resize_to_limit(attempt[:max_side], attempt[:max_side])
        .convert(attempt[:format])

      pipeline = pipeline.saver(quality: attempt[:quality]) if attempt[:quality]
      result = pipeline.call

      processed = result.read
      result.close

      base64_size = (processed.bytesize * 4.0 / 3).ceil
      Rails.logger.info("[PhotoImport] Attempt #{attempt[:format]}@#{attempt[:max_side]}: #{processed.bytesize} bytes (base64: ~#{base64_size})")

      if base64_size <= MAX_BASE64_BYTES
        @content_type = "image/#{attempt[:format]}"
        Rails.logger.info("[PhotoImport] Image ready: #{original_size} → #{processed.bytesize} bytes")
        return processed
      end
    end

    # Last resort
    result = ImageProcessing::Vips
      .source(tempfile.path)
      .autorot
      .resize_to_limit(1024, 1024)
      .convert("jpeg")
      .saver(quality: 75)
      .call
    processed = result.read
    result.close
    @content_type = "image/jpeg"
    Rails.logger.info("[PhotoImport] Image ready (last resort): #{original_size} → #{processed.bytesize} bytes")
    processed
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  def autorot_only(image_data)
    tempfile = Tempfile.new([ "autorot", extension_for(@content_type) ], binmode: true)
    tempfile.write(image_data)
    tempfile.rewind

    result = ImageProcessing::Vips
      .source(tempfile.path)
      .autorot
      .call

    processed = result.read
    result.close

    # Check if autorot made it bigger
    base64_size = (processed.bytesize * 4.0 / 3).ceil
    if base64_size <= MAX_BASE64_BYTES
      @content_type = Marcel::MimeType.for(StringIO.new(processed)) || @content_type
      processed
    else
      image_data
    end
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  # Claude Sonnet 4 pricing (USD per million tokens)
  INPUT_COST_PER_M = 3.0
  OUTPUT_COST_PER_M = 15.0

  def track_usage(response)
    usage = response.usage
    @total_input_tokens += usage.input_tokens
    @total_output_tokens += usage.output_tokens
  end

  def extension_for(content_type)
    case content_type
    when "image/jpeg" then ".jpg"
    when "image/png" then ".png"
    when "image/webp" then ".webp"
    when "image/heic", "image/heif" then ".heic"
    else ".jpg"
    end
  end

  def client
    @client ||= Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
  end
end
