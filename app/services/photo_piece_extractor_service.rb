class PhotoPieceExtractorService
  # Shared JSON format instruction with concrete example
  JSON_FORMAT = <<~FORMAT.freeze
    ## FORMAT DE SORTIE

    Réponds UNIQUEMENT en JSON valide, sans markdown (pas de ```), sans commentaire, sans texte avant ou après.

    Le JSON doit avoir exactement cette structure :

    {"pieces": [{"nom": "Côté", "longueur": 750, "largeur": 500, "quantite": 2, "materiau": null, "confiance": "haute"}, {"nom": "Étagère", "longueur": 1200, "largeur": 300, "quantite": 4, "materiau": "mélaminé", "confiance": "moyenne"}]}

    Champs obligatoires pour chaque pièce :
    - nom : string, label tel qu'écrit sur l'image (ex: "P1", "A", "Côté G"), sinon rôle du panneau
    - longueur : number, en mm, TOUJOURS >= largeur
    - largeur : number, en mm, TOUJOURS <= longueur
    - quantite : number, entier >= 1
    - materiau : string ou null
    - confiance : "haute", "moyenne" ou "basse"
  FORMAT

  # Step 1: Router — classify the image type with a cheap, fast call
  ROUTER_PROMPT = <<~PROMPT.freeze
    Classifie cette image dans UNE des catégories suivantes :

    - "plan_2d" : plan 2D technique, vue éclatée, logiciel CAO (SketchUp, Fusion 360...), rectangles cotés individuellement disposés sur une page — chaque rectangle est UN panneau distinct
    - "meuble_2d" : plan technique d'un meuble avec PLUSIEURS VUES du même objet (face, dessus, côté, perspective) et des cotes structurelles (épaisseurs, dimensions internes). Souvent un titre comme "cabinet", "bookshelf", "commode"
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
    6. Utilise le label EXACT écrit sur l'image comme nom (ex: "P1", "A", "Côté G"). S'il n'y a aucun label, utilise "Panneau A", "Panneau B"...

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
    Tu es un expert menuisier. L'image montre un meuble en 3D (croquis à main levée, perspective, photo).
    Ton rôle : extraire UNIQUEMENT les panneaux labelisés + le fond/dos.

    ## RÈGLES DE LECTURE

    0. NOM = LABEL DU CROQUIS
      Utilise le label EXACT écrit sur le croquis comme nom de pièce (ex: "P1", "A", "Côté G").
      Ne renomme JAMAIS un panneau labelisé — garde le texte tel quel.
      S'il n'y a aucun label, utilise le rôle du panneau (ex: "Côté", "Dessus").

    1. LABELS IDENTIQUES = DIMENSIONS IDENTIQUES
      Si plusieurs panneaux portent le même label (P1, P2, A...),
      ils ont exactement les mêmes dimensions.
      Fusionne-les en une seule ligne, quantite = nombre total d'occurrences.

    2. VUE 3D = FACES CACHÉES EXISTENT PAR SYMÉTRIE
      Le dessin est en perspective : les panneaux non visibles existent forcément.
      - 1 côté visible → 2 côtés au total
      - 1 dessus visible → dessus + dessous au total (quantité = 2)
      Applique cette symétrie TOUJOURS (avec ou sans labels).

    3. POSITION DE LA COTE = ÉLÉMENT CONCERNÉ
      Une cote est toujours annotée au milieu de l'élément qu'elle mesure.
      Ne réaffecte jamais une cote à un autre élément.

    4. NE JAMAIS INVENTER DE PIÈCE SUPPLÉMENTAIRE
      A) Si le croquis CONTIENT des labels (P1, P2, A...) :
         → N'inclus QUE les panneaux labelisés + le fond/dos.
         → Les séparateurs, étagères, cloisons SANS label = IGNORER.
      B) Si le croquis NE CONTIENT AUCUN label :
         → Décompose le meuble par rôle (Côté, Dessus, Façade tiroir, Fond...).
         → N'ajoute PAS de séparateurs internes ni d'étagères non visibles.
      Dans les DEUX cas : les lignes qui divisent l'espace intérieur = IGNORER.

    5. UNIQUEMENT L'EXTÉRIEUR
      N'inclus pas les éléments intérieurs non visibles
      (fond de tiroir, quincaillerie, glissières...).

    ## MÉTHODE

    Étape 1 — Identifier le type de meuble (étagère, armoire, commode, caisson...)
    Étape 2 — Relever toutes les cotes écrites et leur élément associé (règle 3)
    Étape 3 — Pour CHAQUE label distinct, identifier son RÔLE sur le meuble :
      - Où est-il placé ? (face avant = façade, dessus = dessus, côté = côté)
      - Chaque label DIFFÉRENT = une pièce DIFFÉRENTE avec ses propres dimensions.
        Ex: P1 en façade, P2 sur le dessus, P3 sur le côté → 3 lignes séparées.
      - Ne JAMAIS fusionner des labels différents (P1 ≠ P2 ≠ P3).
      - Seuls les labels IDENTIQUES se fusionnent (règle 1).
      Puis appliquer la symétrie (règle 2) :
      - Dessus visible avec label → quantité = 2 (dessus + dessous)
      - Côté visible avec label → quantité = 2 (gauche + droit)
      - Ajouter le fond/dos (×1, seule pièce sans label autorisée)
      Si AUCUN label : décomposer par rôle :
      - N façades empilées en face avant = N façades de tiroir
      - Côtés = 2, Dessus + Dessous = 2, Fond = 1
    Étape 4 — Calculer la hauteur totale :
      Compter le NOMBRE DE COTES de hauteur écrites sur le côté du meuble.
      Ce nombre = nombre de rangées (tiroirs, compartiments).
      Ex: 4 cotes de "20 cm" → 4 rangées → hauteur_totale = 4 × 200 = 800 mm.
      ATTENTION : ne PAS compter les lignes de séparation. Compter les COTES ÉCRITES.
      La hauteur_totale doit être utilisée pour Côtés ET Fond.
    Étape 5 — Calculer les dimensions de chaque panneau SÉPARÉMENT :
      - Façades/Portes : largeur_meuble × hauteur_d_une_rangée
      - Côtés : hauteur_totale (étape 4) × profondeur
      - Dessus/Dessous : largeur × profondeur — TOUJOURS quantité = 2 (dessus + dessous)
      - Fond/Dos : largeur × hauteur_totale (étape 4)
      IMPORTANT :
      - Ne JAMAIS fusionner Côtés et Dessus/Dessous. Ce sont des pièces DIFFÉRENTES.
      - Les Côtés utilisent la hauteur_totale, PAS la hauteur d'une rangée.
        Ex: 3 tiroirs de 10 cm → hauteur_totale = 30 cm → Côté = 300 × profondeur.

    #{JSON_FORMAT}

    ## RÈGLES CRITIQUES

    - Utilise UNIQUEMENT les cotes écrites sur l'image — jamais la perspective visuelle
    - Longueur >= largeur toujours
    - Convertis en mm (1 cm = 10 mm, 1 pouce = 25.4 mm)
    - Si des labels existent sur le croquis, ne retourne JAMAIS un panneau sans label (sauf fond/dos)
    - L'épaisseur du panneau n'est PAS une dimension de découpe
    - Si une dimension est déduite (non cotée), confiance = "moyenne"
    - Si une dimension est incertaine, confiance = "basse"
  PROMPT

  # Step 2c: Agent Meuble 2D — plan technique multi-vues d'un meuble
  MEUBLE_2D_PROMPT = <<~PROMPT.freeze
    Tu es un expert menuisier. L'image montre un PLAN TECHNIQUE d'un meuble avec plusieurs vues
    (face, dessus, côté, perspective). Ces vues montrent LE MÊME meuble sous différents angles.
    Ton rôle : croiser les vues pour extraire la liste des panneaux plats à découper.

    ## PRINCIPES

    1. PLUSIEURS VUES = UN SEUL MEUBLE
      Ne PAS traiter chaque vue comme un meuble séparé.
      Les vues se complètent : la vue de face donne largeur + hauteur,
      la vue de dessus donne largeur + profondeur, la vue de côté donne profondeur + hauteur.

    2. DIMENSIONS GLOBALES EN PREMIER
      Si les dimensions globales sont indiquées (ex: "595 x 349 x 750 mm"),
      les utiliser comme référence : largeur × profondeur × hauteur.

    3. COTES INTERNES = DIMENSIONS DES PANNEAUX
      Les cotes internes sur les vues donnent les dimensions réelles des panneaux
      (qui sont plus petites que les dimensions extérieures à cause de l'épaisseur).
      Privilégier les cotes internes quand elles existent.

    ## MÉTHODE

    Étape 1 — Lire les dimensions globales du meuble (largeur × profondeur × hauteur)
    Étape 2 — Identifier les vues disponibles (face, dessus, côté, perspective)
    Étape 3 — Sur la VUE DE FACE, identifier les panneaux :
      - Côtés verticaux (gauche + droit) → lire hauteur et épaisseur
      - Dessus et dessous → lire largeur et épaisseur
      - Étagères/séparateurs horizontaux → lire largeur interne
      - Séparateurs verticaux → lire hauteur interne
      - Fond/dos
    Étape 4 — Sur la VUE DE DESSUS, lire la profondeur de chaque panneau
    Étape 5 — Sur la VUE DE CÔTÉ, confirmer/compléter les hauteurs et profondeurs
    Étape 6 — Calculer les dimensions finales de chaque panneau :
      - Côtés : hauteur_totale × profondeur
      - Dessus/Dessous : largeur_totale × profondeur
      - Étagères internes : largeur_interne × profondeur_interne
      - Séparateurs verticaux : hauteur_interne × profondeur_interne
      - Fond/Dos : largeur_interne × hauteur_interne
    Étape 7 — Fusionner les panneaux de mêmes dimensions

    #{JSON_FORMAT}

    ## RÈGLES CRITIQUES

    - CROISER les vues : ne jamais extraire d'une seule vue
    - Utilise UNIQUEMENT les cotes écrites — jamais la perspective visuelle
    - Longueur >= largeur toujours
    - Les cotes sont généralement en mm sauf indication contraire
    - Convertis en mm si nécessaire (1 cm = 10 mm)
    - Épaisseur du panneau (souvent 17 ou 18 mm) = PAS une dimension de découpe
    - confiance "haute" si les 2 dimensions viennent de cotes écrites
    - confiance "moyenne" si une dimension est déduite
    - confiance "basse" si incertaine
  PROMPT

  # Step 2d: Agent Liste — tableau ou liste de dimensions
  LISTE_PROMPT = <<~PROMPT.freeze
    L'image montre un tableau ou une liste de dimensions de pièces à découper.

    ## MÉTHODE — SUIVRE DANS L'ORDRE

    Étape 1 — LIRE TOUS LES EN-TÊTES de gauche à droite.
      Avant de lire les données, liste mentalement CHAQUE colonne du tableau.
      Un tableau de découpe a souvent ces colonnes :
      N° | Description | Longueur (Lg) | Largeur (Larg) | Épaisseur (Ep) | Qté | Matière
      ATTENTION : Lg et Larg sont DEUX colonnes distinctes côte à côte.
      L'épaisseur (Ep) est souvent une 3ème colonne numérique → L'IGNORER.

    Étape 2 — Pour CHAQUE LIGNE du tableau, lire TOUTES les cellules de gauche à droite.
      Vérifier que chaque valeur correspond bien à sa colonne (en-tête).
      Un tableau avec 7 colonnes doit donner 7 valeurs par ligne.

    Étape 3 — Chaque ligne = une pièce séparée avec son propre nom.
      Ne JAMAIS fusionner deux lignes, même si elles ont les mêmes dimensions.
      Ex: "C001 - Côté gauche" et "C002 - Côté droit" = 2 pièces distinctes de qté 1.

    #{JSON_FORMAT}

    ## RÈGLES
    - Longueur >= largeur toujours
    - Convertis en mm si nécessaire (1 cm = 10 mm, 1 pouce = 25.4 mm)
    - Si pas d'unité indiquée et les valeurs sont > 100, considérer qu'elles sont en mm
    - Utilise le libellé EXACT de la ligne comme nom (ex: "C001 - Côté gauche")
      S'il y a un N° de pièce ET une description, combiner les deux
    - quantite = la colonne quantité si présente, sinon 1
    - L'épaisseur N'EST PAS une dimension de découpe → ne pas l'utiliser comme longueur ou largeur
    - confiance "haute" si lisible, "basse" si incertaine
  PROMPT

  AGENT_PROMPTS = {
    "plan_2d" => PLAN_2D_PROMPT,
    "meuble_2d" => MEUBLE_2D_PROMPT,
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

    # DEBUG: save the image sent to the API
    if Rails.env.development?
      ext = extension_for(@content_type)
      debug_path = Rails.root.join("tmp", "debug_api_image#{ext}")
      File.binwrite(debug_path, @image_data)
      Rails.logger.info("[PhotoImport] DEBUG: image saved to #{debug_path} (#{@image_data.bytesize} bytes)")
    end
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
