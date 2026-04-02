require "net/http"

class BrevoService
  EVENTS_URL = "https://api.brevo.com/v3/events"

  def self.sync_contact(user)
    api = Brevo::ContactsApi.new

    attributes = {
      "LOCALE" => user.locale,
      "PLAN" => user.plan,
      "SIGNUP_DATE" => user.created_at&.iso8601
    }
    create_contact = Brevo::CreateContact.new(
      email: user.email,
      attributes: attributes,
      update_enabled: true
    )

    api.create_contact(create_contact)
  rescue Brevo::ApiError => e
    Rails.logger.error("[BrevoService#sync_contact] API error for #{user.email}: #{e.message}")
  rescue StandardError => e
    Rails.logger.error("[BrevoService#sync_contact] Unexpected error for #{user.email}: #{e.message}")
  end

  def self.track_event(email:, event_name:, properties: {})
    uri = URI(EVENTS_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.path, {
      "api-key" => ENV["BREVO_API_KEY"],
      "Content-Type" => "application/json"
    })
    request.body = {
      event_name: event_name,
      event_properties: properties,
      identifiers: { email_id: email }
    }.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error("[BrevoService#track_event] HTTP #{response.code} for event '#{event_name}': #{response.body}")
    end
  rescue StandardError => e
    Rails.logger.error("[BrevoService#track_event] Error sending event '#{event_name}' for #{email}: #{e.message}")
  end
end
