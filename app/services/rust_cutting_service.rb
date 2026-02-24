require "net/http"

class RustCuttingService
  OPTIMIZER_URL = ENV.fetch("OPTIMIZER_URL", "http://localhost:3001/optimize")

  PIECE_DOES_NOT_FIT = /\bpiece (\d+x\d+) does not fit in stock (\d+x\d+)\b/

  def self.optimize(stock:, cuts:, kerf: 0, cut_direction: "auto", grain_direction: "none")
    payload = {
      stock: { length: stock[:l].to_i, width: stock[:w].to_i, grain: grain_direction },
      cuts: cuts.map { |c|
        {
          rect: { length: c[:l].to_i, width: c[:w].to_i },
          qty: c[:qty].to_i,
          grain: c[:grain] || "auto"
        }
      },
      kerf: kerf.to_f,
      cut_direction: cut_direction
    }

    uri = URI(OPTIMIZER_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 5
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
    request.body = payload.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise translate_error(response.body)
    end

    JSON.parse(response.body)
  end

  def self.translate_error(body)
    if (match = body.match(PIECE_DOES_NOT_FIT))
      I18n.t("optimizer_errors.piece_does_not_fit", piece: match[1], stock: match[2])
    else
      I18n.t("optimizer_errors.generic", message: body)
    end
  end
  private_class_method :translate_error
end
