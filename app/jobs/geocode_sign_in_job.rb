class GeocodeSignInJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  def perform(user, ip)
    geo = Geocoder.search(ip).first
    user.update_columns(
      last_sign_in_country: geo&.country,
      last_sign_in_city: geo&.city
    )
  rescue StandardError => e
    Rails.logger.warn("Geolocation failed for IP #{ip}: #{e.message}")
  end
end
