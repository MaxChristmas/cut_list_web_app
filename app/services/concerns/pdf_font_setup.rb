module PdfFontSetup
  FONT_DIR = Rails.root.join("app/assets/fonts/noto-sans-jp").freeze

  def setup_fonts(pdf)
    pdf.font_families.update(
      "NotoSansJP" => {
        normal: FONT_DIR.join("NotoSansJP-Regular.ttf").to_s,
        bold:   FONT_DIR.join("NotoSansJP-Bold.ttf").to_s
      }
    )
    pdf.font "NotoSansJP"
  end
end
