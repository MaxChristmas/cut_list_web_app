require "net/http"

class RustCuttingService
  OPTIMIZER_URL = ENV.fetch("OPTIMIZER_URL", "http://localhost:3001/optimize")
  DIRECTION_MAP = {
    "along_length" => "along_width",
    "along_width" => "along_length"
  }.freeze

  def self.optimize(stock:, cuts:, kerf: 0, cut_direction: "auto", allow_rotate: true)
    payload = {
      stock: { length: stock[:l].to_i, width: stock[:w].to_i },
      cuts: cuts.map { |c|
        {
          rect: { length: c[:l].to_i, width: c[:w].to_i },
          qty: c[:qty].to_i
        }
      },
      kerf: kerf.to_f,
      cut_direction: DIRECTION_MAP[cut_direction] || cut_direction,
      allow_rotate: allow_rotate
    }

    uri = URI(OPTIMIZER_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 5
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
    request.body = payload.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise "Optimizer returned #{response.code}: #{response.body}"
    end

    JSON.parse(response.body)
  end
end
