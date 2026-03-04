class NtfyOptimizationJob < ApplicationJob
  discard_on StandardError

  def perform(user, optimization)
    topic = ENV.fetch("NTFY_TOPIC") { return }

    location = [user.last_sign_in_city, user.last_sign_in_country].compact.join(", ")
    location = "Unknown" if location.blank?

    title = "New optimization"
    message = [
      "Email: #{user.email}",
      "Time: #{optimization.created_at.strftime('%b %d, %Y at %H:%M UTC')}",
      "Location: #{location}",
      "Sheets: #{optimization.sheets_count} | Efficiency: #{optimization.efficiency&.round(1)}%"
    ].join("\n")

    uri = URI("https://ntfy.sh/#{topic}")
    request = Net::HTTP::Post.new(uri)
    request.body = message
    request["Title"] = title
    request["Tags"] = "scissors"

    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
      http.request(request)
    end
  end
end
