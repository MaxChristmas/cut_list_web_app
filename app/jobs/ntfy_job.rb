class NtfyJob < ApplicationJob
  discard_on StandardError

  def perform(title, message, tags = "bell")
    topic = ENV.fetch("NTFY_TOPIC") { return }

    uri = URI("https://ntfy.sh/#{topic}")
    request = Net::HTTP::Post.new(uri)
    request.body = message
    request["Title"] = title
    request["Tags"] = tags

    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
      http.request(request)
    end
  end
end
