require "net/http"

class RustCuttingService
  OPTIMIZER_URL = ENV.fetch("OPTIMIZER_URL", "http://localhost:3001/optimize")

  def self.optimize(stock:, cuts:, kerf: 0)
    payload = {
      stock: { w: stock[:w].to_i, h: stock[:h].to_i },
      cuts: cuts.map { |c|
        {
          rect: { w: c[:w].to_i, h: c[:h].to_i },
          qty: c[:qty].to_i,
          allow_rotate: c[:allow_rotate] || false
        }
      },
      kerf: kerf.to_f
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
